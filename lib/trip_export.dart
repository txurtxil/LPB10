// trip_export.dart
//
// Exporta el historico de rutas a un PDF: portada con totales del periodo,
// y una tarjeta compacta por ruta con su mapa, km, consumo y coste estimado
// segun el precio configurado ese dia.
//
// HISTORIA DE ESTE FICHERO (para no repetir errores ya cometidos):
//  - v3.60.133: primer intento, esquema vectorial propio (sin mapa real,
//    sin conexion). El trazado no se veia: CustomPaint en el paquete pdf
//    no hereda tamano de su contenedor, quedaba en un lienzo PdfPoint.zero.
//  - v3.60.134: fix del tamano. El trazado se via bien en pantalla real.
//  - v3.60.135: mejoras visuales (fondo, rejilla, flecha, escala, norte),
//    todas sobre el mismo esquema vectorial. Un intento de escribir texto
//    con canvas.setFont(pw.Font...) fallo en flutter analyze: setFont
//    espera un PdfFont de bajo nivel, no un pw.Font de widgets. Se quito.
//  - v3.60.136: las rutas reconstruidas (sin linea, por no inventar el
//    trayecto) empezaron a mostrar al menos sus puntos reales conocidos.
//  - 10/09/2026: peticion explicita de mapa real de fondo (OpenStreetMap),
//    no solo el esquema. Este cambio:
//      - Descarga mosaicos de tile.openstreetmap.org SOLO en el momento de
//        exportar (deja de ser 100% offline, a diferencia de las versiones
//        anteriores).
//      - Compone los mosaicos con el paquete 'image', recorta y escala al
//        tamano exacto de cada tarjeta.
//      - Dibuja el trazado vectorial ENCIMA de esa imagen, proyectando con
//        la misma matematica de Web Mercator que usan los mosaicos (no la
//        proyeccion simplificada de las versiones anteriores), para que
//        linea y mapa coincidan en el mismo lugar.
//      - Si la descarga falla por cualquier motivo (sin red, timeout,
//        mosaico no disponible), esa tarjeta en concreto cae SOLA al
//        esquema vectorial de las versiones anteriores. Nunca rompe el PDF
//        entero por un fallo de red puntual.
//      - Respeta la politica de uso de OpenStreetMap: User-Agent que
//        identifica la app, descargas secuenciales (nunca en paralelo),
//        cache de mosaicos compartida durante toda la exportacion (rutas
//        cercanas reutilizan los mismos mosaicos), y un tope global de
//        mosaicos por exportacion para no descargar sin limite si se pide
//        "todo el historico". Atribucion "(c) OpenStreetMap" en cada
//        tarjeta que use un mosaico real.
//
// AVISO DE HONESTIDAD (10/09/2026, sin poder compilar ni ver en pantalla
// antes de entregar este fichero): el mapa y la linea se dibujan los DOS a
// traves del mismo canvas de bajo nivel (PdfGraphics), con las mismas
// coordenadas, precisamente para que encajen entre si pase lo que pase con
// el eje vertical de ese canvas. Lo que NO se puede saber sin verlo en
// pantalla es si ese eje esta invertido respecto a como se ve un mapa
// normal (norte arriba). Si el mapa sale con el norte hacia abajo, es un
// solo signo que cambiar en _latAGlobalPixelY, no un realineado completo,
// porque mapa y linea se moverian juntos al cambiarlo.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data' show Uint8List;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'trip_rebuild.dart';
import 'energy_cost.dart' show preciosPorDia;
import 'daily_stats.dart' show DailyStats;

const _pdfBlue = PdfColor.fromInt(0xFF0D3B66);
const _pdfGood = PdfColor.fromInt(0xFF2A9D8F);
const _pdfOver = PdfColor.fromInt(0xFFE76F51);
const _pdfGrey = PdfColor.fromInt(0xFF9AA5B1);
const _pdfMapBg = PdfColor.fromInt(0xFFEFF3F6);
const _pdfMapGrid = PdfColor.fromInt(0xFFDCE3E8);

// User-Agent que identifica la app, exigido por la politica de uso de
// OpenStreetMap (operations.osmfoundation.org/policies/tiles/).
const _osmUserAgent = 'LMB10-unofficial-app (github.com/txurtxil/LPB10)';
const _osmTileUrl = 'https://tile.openstreetmap.org';

// Tope de mosaicos descargados en TODA la exportacion, sin importar cuantas
// rutas se pidan. Con "todo el historico" (80+ rutas) sin este tope se
// podria golpear el servidor gratuito de OSM con cientos de peticiones de
// golpe. Las rutas que se queden sin presupuesto caen al esquema vectorial,
// igual que si hubiera fallado la red.
const _maxMosaicosPorExportacion = 120;

class _RangoExport {
  final String label;
  final int? diasAtras; // null = todo el historico
  const _RangoExport(this.label, this.diasAtras);
}

/// Pregunta el rango a exportar. Devuelve null si el usuario cancela.
Future<List<RouteTrip>?> _elegirRango(
    BuildContext context, List<RouteTrip> todas, bool es) async {
  final opciones = [
    _RangoExport(es ? 'Ultimos 7 dias' : 'Last 7 days', 7),
    _RangoExport(es ? 'Ultimos 30 dias' : 'Last 30 days', 30),
    _RangoExport(es ? 'Todo el historico' : 'Entire history', null),
  ];
  final elegido = await showDialog<_RangoExport>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(es ? 'Exportar rutas' : 'Export trips'),
      children: [
        for (final o in opciones)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, o),
            child: Text(o.label),
          ),
      ],
    ),
  );
  if (elegido == null) return null;
  if (elegido.diasAtras == null) return todas;
  final corte = DateTime.now()
      .subtract(Duration(days: elegido.diasAtras!))
      .millisecondsSinceEpoch;
  return todas.where((r) => r.startTs >= corte).toList();
}

String _fechaHoraLarga(int ts, bool es) {
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  const mesesEs = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
  const mesesEn = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  final mes = es ? mesesEs[d.month - 1] : mesesEn[d.month - 1];
  String two(int n) => n.toString().padLeft(2, '0');
  return es
      ? '${two(d.day)} $mes ${d.year}, ${two(d.hour)}:${two(d.minute)}'
      : '$mes ${two(d.day)}, ${d.year}, ${two(d.hour)}:${two(d.minute)}';
}

// ============================================================
// Matematica de mosaicos Web Mercator (formulas estandar, las mismas que
// usa cualquier mapa deslizante: OSM, Google Maps, etc.)
// ============================================================

double _lonAGlobalPixelX(double lon, int zoom) =>
    (lon + 180.0) / 360.0 * (256 << zoom);

double _latAGlobalPixelY(double lat, int zoom) {
  final latRad = lat * math.pi / 180.0;
  final n = (256 << zoom).toDouble();
  return (1.0 - math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) / 2.0 * n;
}

int _lonATileX(double lon, int zoom) =>
    ((lon + 180.0) / 360.0 * (1 << zoom)).floor();

int _latATileY(double lat, int zoom) {
  final latRad = lat * math.pi / 180.0;
  final n = (1 << zoom).toDouble();
  return ((1.0 - math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) / 2.0 * n).floor();
}

double _haversineMetros(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLon = (lon2 - lon1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) *
          math.sin(dLon / 2) * math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return r * c;
}

/// Resultado de preparar el mapa de una ruta: o bien una imagen real de OSM
/// lista para dibujar mas los puntos ya proyectados en el mismo espacio de
/// coordenadas, o bien null si hubo que renunciar (sin red, fallo, o
/// presupuesto de mosaicos agotado) -- en ese caso la tarjeta debe usar el
/// esquema vectorial de siempre como respaldo.
class _MapaPreparado {
  // PdfImage ya construido, no los bytes crudos: PdfGraphics.page no existe
  // (error real de flutter analyze, 10/09/2026), asi que el PdfImage no se
  // puede construir DENTRO del painter -- necesita el pw.Document padre,
  // que solo esta disponible aqui, en exportarRutasPdf, antes de que se
  // arme cada pagina.
  final PdfImage pdfImage;
  final List<PdfPoint> puntos; // uno por waypoint original, mismo orden
  const _MapaPreparado(this.pdfImage, this.puntos);
}

/// Descarga (con cache) los mosaicos necesarios para encuadrar 'wps' dentro
/// de un lienzo de 'targetSize' puntos PDF, los compone en una sola imagen,
/// recorta y escala, y devuelve tanto la imagen como los waypoints ya
/// proyectados en ese mismo espacio de pixeles. Devuelve null si algo falla
/// o si no queda presupuesto de mosaicos.
Future<_MapaPreparado?> _prepararMapaReal(
  List<RouteWaypoint> wps,
  PdfPoint targetSize,
  http.Client client,
  Map<String, Uint8List> cacheMosaicos,
  _PresupuestoMosaicos presupuesto,
  pw.Document doc,
) async {
  if (wps.isEmpty) return null;
  try {
    // Un solo punto: se sintetiza un area pequena (~150 m) alrededor para
    // poder pedir mosaicos, aunque no haya nada que conectar con linea.
    double latMin, latMax, lonMin, lonMax;
    if (wps.length == 1) {
      const delta = 0.0015; // approx 150-160 m en latitud
      latMin = wps.first.lat - delta;
      latMax = wps.first.lat + delta;
      lonMin = wps.first.lon - delta;
      lonMax = wps.first.lon + delta;
    } else {
      final lats = wps.map((w) => w.lat).toList();
      final lons = wps.map((w) => w.lon).toList();
      latMin = lats.reduce(math.min);
      latMax = lats.reduce(math.max);
      lonMin = lons.reduce(math.min);
      lonMax = lons.reduce(math.max);
      // Margen del 18% del vano, con un minimo absoluto para trayectos muy
      // cortos o casi rectos (evita un area degenerada de ancho/alto cero).
      final padLat = math.max((latMax - latMin) * 0.18, 0.0008);
      final padLon = math.max((lonMax - lonMin) * 0.18, 0.0008);
      latMin -= padLat;
      latMax += padLat;
      lonMin -= padLon;
      lonMax += padLon;
    }

    final latAvg = (latMin + latMax) / 2;
    final lonAvg = (lonMin + lonMax) / 2;
    final anchoMetros = math.max(_haversineMetros(latAvg, lonMin, latAvg, lonMax), 30.0);
    final altoMetros = math.max(_haversineMetros(latMin, lonAvg, latMax, lonAvg), 30.0);

    // Resolucion final: 3x el tamano en puntos PDF, para que se vea nitido
    // al imprimir/hacer zoom, sin descargar mosaicos de mas resolucion de
    // la que hace falta.
    final pxObjetivoW = (targetSize.x * 3).round().clamp(60, 900);
    final pxObjetivoH = (targetSize.y * 3).round().clamp(60, 900);

    final metrosPorPixel = math.max(anchoMetros / pxObjetivoW, altoMetros / pxObjetivoH);
    // Formula estandar de "zoom que encaja": 156543.03392 m/px es la
    // resolucion en el ecuador a zoom 0.
    var zoom = (math.log(156543.03392 * math.cos(latAvg * math.pi / 180) / metrosPorPixel) /
            math.log(2))
        .floor()
        .clamp(3, 18);

    int tx0 = _lonATileX(lonMin, zoom);
    int tx1 = _lonATileX(lonMax, zoom);
    int ty0 = _latATileY(latMax, zoom); // norte = fila mas pequena
    int ty1 = _latATileY(latMin, zoom);
    // Tope de 2x2 mosaicos por ruta: si el area pedida es mayor a eso a
    // este zoom, se baja de zoom (menos detalle, pero menos descargas)
    // hasta encajar, o hasta el zoom minimo aceptable.
    while ((tx1 - tx0 + 1) * (ty1 - ty0 + 1) > 4 && zoom > 3) {
      zoom--;
      tx0 = _lonATileX(lonMin, zoom);
      tx1 = _lonATileX(lonMax, zoom);
      ty0 = _latATileY(latMax, zoom);
      ty1 = _latATileY(latMin, zoom);
    }

    final cols = tx1 - tx0 + 1;
    final rows = ty1 - ty0 + 1;
    if (presupuesto.restantes < cols * rows) return null;

    final compuesta = img.Image(width: cols * 256, height: rows * 256);
    for (var ty = ty0; ty <= ty1; ty++) {
      for (var tx = tx0; tx <= tx1; tx++) {
        final clave = '$zoom/$tx/$ty';
        var bytes = cacheMosaicos[clave];
        if (bytes == null) {
          presupuesto.restantes--;
          final resp = await client
              .get(Uri.parse('$_osmTileUrl/$zoom/$tx/$ty.png'),
                  headers: {'User-Agent': _osmUserAgent})
              .timeout(const Duration(seconds: 6));
          if (resp.statusCode != 200) return null;
          bytes = resp.bodyBytes;
          cacheMosaicos[clave] = bytes;
        }
        final mosaico = img.decodeImage(bytes);
        if (mosaico == null) return null;
        img.compositeImage(compuesta, mosaico,
            dstX: (tx - tx0) * 256, dstY: (ty - ty0) * 256);
      }
    }

    final origenPxX = tx0 * 256.0;
    final origenPxY = ty0 * 256.0;
    final centroPxX = (_lonAGlobalPixelX(lonMin, zoom) + _lonAGlobalPixelX(lonMax, zoom)) / 2 - origenPxX;
    final centroPxY = (_latAGlobalPixelY(latMax, zoom) + _latAGlobalPixelY(latMin, zoom)) / 2 - origenPxY;

    final aspectoObjetivo = pxObjetivoW / pxObjetivoH;
    var cropW = (compuesta.width).toDouble();
    var cropH = cropW / aspectoObjetivo;
    if (cropH > compuesta.height) {
      cropH = compuesta.height.toDouble();
      cropW = cropH * aspectoObjetivo;
    }
    var cropX = centroPxX - cropW / 2;
    var cropY = centroPxY - cropH / 2;
    cropX = cropX.clamp(0.0, math.max(0.0, compuesta.width - cropW));
    cropY = cropY.clamp(0.0, math.max(0.0, compuesta.height - cropH));

    final recortada = img.copyCrop(compuesta,
        x: cropX.round(), y: cropY.round(),
        width: cropW.round().clamp(1, compuesta.width - cropX.round()),
        height: cropH.round().clamp(1, compuesta.height - cropY.round()));
    final final_ = img.copyResize(recortada, width: pxObjetivoW, height: pxObjetivoH);
    // PdfImage se construye AQUI, con doc.document (el PdfDocument real de
    // bajo nivel detras del pw.Document de alto nivel), no dentro del
    // painter -- ver comentario en _MapaPreparado.
    final pdfImage = PdfImage(doc.document,
        image: final_.getBytes(order: img.ChannelOrder.rgba),
        width: final_.width, height: final_.height);

    final escalaX = pxObjetivoW / cropW;
    final escalaY = pxObjetivoH / cropH;
    final pixelesPorPunto = pxObjetivoW / targetSize.x;

    final puntos = <PdfPoint>[];
    for (final w in wps) {
      final gx = _lonAGlobalPixelX(w.lon, zoom) - origenPxX;
      final gy = _latAGlobalPixelY(w.lat, zoom) - origenPxY;
      final finalPixX = (gx - cropX) * escalaX;
      final finalPixY = (gy - cropY) * escalaY;
      // Mismo espacio de pixeles top-down que la imagen (fila 0 = arriba).
      // Ver aviso de honestidad al principio del fichero sobre esta
      // eleccion de eje.
      puntos.add(PdfPoint(finalPixX / pixelesPorPunto, finalPixY / pixelesPorPunto));
    }
    return _MapaPreparado(pdfImage, puntos);
  } catch (_) {
    return null;
  }
}

class _PresupuestoMosaicos {
  int restantes;
  _PresupuestoMosaicos(this.restantes);
}

/// Punto de entrada: pide el rango, genera el PDF y abre la hoja de
/// compartir. 'todas' debe ser el historico COMPLETO, no una version capada.
Future<void> exportarRutasPdf(BuildContext context, List<RouteTrip> todas) async {
  final es = Localizations.localeOf(context).languageCode == 'es';
  if (todas.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(es ? 'No hay rutas que exportar.' : 'No trips to export.')));
    return;
  }
  final rutas = await _elegirRango(context, todas, es);
  if (rutas == null || rutas.isEmpty || !context.mounted) return;

  if (rutas.length > 80) {
    final continuar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(es ? 'Bastantes rutas' : 'Quite a few trips'),
        content: Text(es
            ? 'Vas a exportar ${rutas.length} rutas. Se descargaran mapas de OpenStreetMap, '
                'asi que hace falta conexion y puede tardar un poco.'
            : 'You are about to export ${rutas.length} trips. Maps will be downloaded from '
                'OpenStreetMap, so an internet connection is needed and it may take a while.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(es ? 'Cancelar' : 'Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(es ? 'Continuar' : 'Continue')),
        ],
      ),
    );
    if (continuar != true || !context.mounted) return;
  }

  final precios = await preciosPorDia();

  // Descarga de mapas ANTES de construir el PDF: el 'painter' de bajo nivel
  // de CustomPaint es sincrono, no puede esperar una peticion de red por
  // dentro. Se prepara todo primero, con una unica cache y un unico
  // presupuesto de mosaicos compartidos por toda la exportacion.
  final doc = pw.Document();
  final client = http.Client();
  final mapas = <_MapaPreparado?>[];
  var usoMapaReal = false;
  try {
    final cache = <String, Uint8List>{};
    final presupuesto = _PresupuestoMosaicos(_maxMosaicosPorExportacion);
    for (final r in rutas) {
      if (r.waypoints.isEmpty) {
        mapas.add(null);
        continue;
      }
      final m = await _prepararMapaReal(
          r.waypoints, _mapaSizeParaGrid(PdfPageFormat.a4), client, cache, presupuesto, doc);
      mapas.add(m);
      if (m != null) usoMapaReal = true;
    }
  } finally {
    client.close();
  }

  double kmTotal = 0, kwhTotal = 0, eurTotal = 0;
  var hayEur = false;
  var conMapa = 0;
  for (final r in rutas) {
    kmTotal += r.km;
    final kwh = r.kwh100 != null ? r.kwh100! * r.km / 100 : null;
    if (kwh != null) {
      kwhTotal += kwh;
      final dia = DailyStats.dayKey(DateTime.fromMillisecondsSinceEpoch(r.startTs));
      final precio = precios[dia];
      if (precio != null) {
        eurTotal += kwh * precio;
        hayEur = true;
      }
    }
    if (r.hasGps) conMapa++;
  }
  final consumoMedio = kmTotal > 0 && kwhTotal > 0 ? kwhTotal / kmTotal * 100 : null;

  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    build: (pwCtx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('LMB10',
            style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: _pdfBlue)),
        pw.SizedBox(height: 4),
        pw.Text(es ? 'Informe de rutas' : 'Trip report',
            style: pw.TextStyle(fontSize: 16, color: _pdfGrey)),
        pw.SizedBox(height: 2),
        pw.Text(
          '${_fechaHoraLarga(rutas.last.startTs, es)}  ->  ${_fechaHoraLarga(rutas.first.startTs, es)}',
          style: pw.TextStyle(fontSize: 11, color: _pdfGrey),
        ),
        pw.SizedBox(height: 24),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _totalBox(es ? 'Rutas' : 'Trips', '${rutas.length}'),
            _totalBox(es ? 'Km totales' : 'Total km', kmTotal.toStringAsFixed(0)),
            _totalBox('kWh', kwhTotal.toStringAsFixed(1)),
            _totalBox('EUR', hayEur ? eurTotal.toStringAsFixed(2) : '--'),
          ],
        ),
        pw.SizedBox(height: 16),
        if (consumoMedio != null)
          pw.Text(
            es
                ? 'Consumo medio del periodo: ${consumoMedio.toStringAsFixed(1)} kWh/100km'
                : 'Average consumption: ${consumoMedio.toStringAsFixed(1)} kWh/100km',
            style: const pw.TextStyle(fontSize: 11),
          ),
        pw.Text(
          es
              ? '$conMapa de ${rutas.length} rutas con recorrido GPS registrado.'
              : '$conMapa of ${rutas.length} trips have a recorded GPS path.',
          style: const pw.TextStyle(fontSize: 11),
        ),
        pw.Spacer(),
        pw.Divider(color: _pdfGrey),
        if (usoMapaReal)
          pw.Text('Mapas: (c) OpenStreetMap contributors',
              style: pw.TextStyle(fontSize: 8, color: _pdfGrey)),
        pw.Text(
          es
              ? 'Energia medida en la bateria del vehiculo. La factura electrica real sera algo '
                  'mayor: cargar tiene perdidas que aqui no se cuentan.'
              : 'Energy measured at the vehicle battery. Your actual electricity bill will be '
                  'somewhat higher: charging losses are not included here.',
          style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: _pdfGrey),
        ),
        pw.Text('LMB10 -- unofficial Leapmotor companion app',
            style: pw.TextStyle(fontSize: 8, color: _pdfGrey)),
      ],
    ),
  ));

  const porPagina = 6;
  for (var i = 0; i < rutas.length; i += porPagina) {
    final finGrupo = math.min(i + porPagina, rutas.length);
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (pwCtx) => pw.GridView(
        crossAxisCount: 2,
        childAspectRatio: 1.35,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        children: [
          for (var j = i; j < finGrupo; j++)
            _rutaCard(rutas[j], mapas[j], precios, es, _mapaSizeParaGrid(PdfPageFormat.a4)),
        ],
      ),
    ));
  }

  final bytes = await doc.save();
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/lmb10_rutas_${DateTime.now().millisecondsSinceEpoch}.pdf');
  await f.writeAsBytes(bytes);
  await SharePlus.instance.share(ShareParams(
    files: [XFile(f.path)],
    subject: es ? 'Rutas LMB10' : 'LMB10 trips',
  ));
}

pw.Widget _totalBox(String label, String value) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(value,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _pdfBlue)),
        pw.Text(label, style: pw.TextStyle(fontSize: 9, color: _pdfGrey)),
      ],
    );

/// Ancho/alto del lienzo del mapa, calculado a mano a partir del ancho de
/// pagina real. Ver historial arriba: CustomPaint no hereda tamano solo.
PdfPoint _mapaSizeParaGrid(PdfPageFormat page) {
  final anchoDisponible = page.width - 48 - 8;
  final anchoCelda = anchoDisponible / 2;
  final anchoMapa = anchoCelda - 8 - 16 - 1;
  return PdfPoint(anchoMapa.clamp(60.0, 400.0), 90);
}

pw.Widget _rutaCard(RouteTrip r, _MapaPreparado? mapa, Map<String, double> precios, bool es, PdfPoint mapaSize) {
  final kwh = r.kwh100 != null ? r.kwh100! * r.km / 100 : null;
  final dia = DailyStats.dayKey(DateTime.fromMillisecondsSinceEpoch(r.startTs));
  final precio = precios[dia];
  final eur = (kwh != null && precio != null) ? kwh * precio : null;

  return pw.Container(
    margin: const pw.EdgeInsets.all(4),
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _pdfGrey, width: 0.5),
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(_fechaHoraLarga(r.startTs, es),
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _pdfBlue)),
        pw.SizedBox(height: 4),
        pw.Container(
          height: mapaSize.y,
          alignment: pw.Alignment.center,
          child: mapa != null
              ? pw.ClipRect(
                  child: pw.CustomPaint(
                    size: mapaSize,
                    painter: (canvas, size) => _dibujarSobreMapaReal(
                        canvas, size, mapa, dibujarLinea: r.hasGps, reconstruida: r.reconstruida, es: es),
                  ),
                )
              : (r.waypoints.isNotEmpty
                  ? pw.Stack(
                      children: [
                        pw.ClipRect(
                          child: pw.CustomPaint(
                            size: mapaSize,
                            painter: (canvas, size) =>
                                _dibujarTrazado(canvas, size, r.waypoints, dibujarLinea: r.hasGps),
                          ),
                        ),
                        pw.Positioned(
                          top: 3,
                          right: 4,
                          child: pw.Text('N',
                              style: pw.TextStyle(
                                  fontSize: 7, fontWeight: pw.FontWeight.bold, color: _pdfGrey)),
                        ),
                        if (r.reconstruida)
                          pw.Positioned(
                            bottom: 2,
                            left: 3,
                            right: 3,
                            child: pw.Text(
                              es ? 'sin trayecto exacto' : 'exact path unknown',
                              style: pw.TextStyle(fontSize: 6, color: _pdfGrey, fontStyle: pw.FontStyle.italic),
                            ),
                          ),
                      ],
                    )
                  : pw.Text(
                      es ? 'Sin datos GPS' : 'No GPS data',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(fontSize: 8, color: _pdfGrey, fontStyle: pw.FontStyle.italic),
                    )),
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('${r.km.toStringAsFixed(0)} km', style: const pw.TextStyle(fontSize: 9)),
            pw.Text(
              r.kwh100 != null ? '${r.kwh100!.toStringAsFixed(1)} kWh/100km' : (es ? 'no fiable' : 'unreliable'),
              style: const pw.TextStyle(fontSize: 9),
            ),
            pw.Text(
              eur != null ? '${eur.toStringAsFixed(2)} EUR' : '--',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _pdfGood),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Dibuja la imagen real de OpenStreetMap ya preparada, mas el trazado
/// encima, usando el MISMO canvas para los dos (ver aviso de honestidad al
/// principio del fichero sobre el eje vertical). canvas.drawImage necesita
/// los bytes ya decodificados; se decodifica aqui con el mismo paquete
/// 'image' que los compuso, para pasar ancho/alto reales a PdfImage.
void _dibujarSobreMapaReal(PdfGraphics canvas, PdfPoint size, _MapaPreparado mapa,
    {required bool dibujarLinea, required bool reconstruida, required bool es}) {
  // El PdfImage ya viene construido desde _prepararMapaReal (con el
  // pw.Document real, al que este painter no tiene acceso). Aqui solo se
  // dibuja: sin try/decodificar de nuevo, nada que pueda fallar salvo que
  // drawImage en si de un problema, en cuyo caso se prefiere dejar que
  // se vea el error a tragarlo en silencio con un fondo liso -- ya no hay
  // bytes crudos que reintentar, sino un objeto ya preparado.
  canvas.drawImage(mapa.pdfImage, 0, 0, size.x, size.y);

  final pts = mapa.puntos;
  if (pts.isEmpty) return;

  if (dibujarLinea && pts.length >= 2) {
    canvas.setStrokeColor(_pdfBlue);
    canvas.setLineWidth(1.5);
    canvas.moveTo(pts.first.x, pts.first.y);
    for (final p in pts.skip(1)) {
      canvas.lineTo(p.x, p.y);
    }
    canvas.strokePath();
  }

  canvas.setColor(_pdfGood);
  canvas.drawEllipse(pts.first.x, pts.first.y, 2.4, 2.4);
  canvas.fillPath();

  if (pts.length >= 2) {
    final fin = pts.last;
    final penultimo = pts[pts.length - 2];
    var rumbo = math.atan2(fin.y - penultimo.y, fin.x - penultimo.x);
    if (fin.x == penultimo.x && fin.y == penultimo.y) rumbo = math.pi / 2;
    const largoFlecha = 5.0, anchoFlecha = 3.2;
    final puntaX = fin.x + math.cos(rumbo) * largoFlecha;
    final puntaY = fin.y + math.sin(rumbo) * largoFlecha;
    final baseAng1 = rumbo + math.pi * 0.75, baseAng2 = rumbo - math.pi * 0.75;
    final b1x = fin.x + math.cos(baseAng1) * anchoFlecha;
    final b1y = fin.y + math.sin(baseAng1) * anchoFlecha;
    final b2x = fin.x + math.cos(baseAng2) * anchoFlecha;
    final b2y = fin.y + math.sin(baseAng2) * anchoFlecha;
    canvas.setColor(_pdfOver);
    canvas.moveTo(puntaX, puntaY);
    canvas.lineTo(b1x, b1y);
    canvas.lineTo(b2x, b2y);
    canvas.lineTo(puntaX, puntaY);
    canvas.fillPath();
  }
}

/// Esquema vectorial de RESPALDO: se usa solo cuando la descarga del mapa
/// real fallo (sin red, timeout, etc.) o cuando no queda presupuesto de
/// mosaicos para esta exportacion. Logica identica a la version anterior
/// (v3.60.135/136), ya confirmada en pantalla real.
void _dibujarTrazado(PdfGraphics canvas, PdfPoint size, List<RouteWaypoint> wps, {bool dibujarLinea = true}) {
  canvas.setColor(_pdfMapBg);
  canvas.drawRect(0, 0, size.x, size.y);
  canvas.fillPath();

  if (wps.length == 1) {
    canvas.setColor(_pdfGood);
    canvas.drawEllipse(size.x / 2, size.y / 2, 2.5, 2.5);
    canvas.fillPath();
    return;
  }

  final lats = wps.map((w) => w.lat).toList();
  final lons = wps.map((w) => w.lon).toList();
  final latMin = lats.reduce(math.min), latMax = lats.reduce(math.max);
  final lonMin = lons.reduce(math.min), lonMax = lons.reduce(math.max);
  final latAvgRad = (latMin + latMax) / 2 * math.pi / 180;
  final corrLon = math.cos(latAvgRad).abs().clamp(0.15, 1.0);

  final anchoGeo = (lonMax - lonMin) * corrLon;
  final altoGeo = latMax - latMin;
  final escala = (anchoGeo > 0 && altoGeo > 0)
      ? math.min(size.x / math.max(anchoGeo, 1e-6), size.y / math.max(altoGeo, 1e-6)) * 0.85
      : 1.0;
  final anchoUsado = anchoGeo * escala, altoUsado = altoGeo * escala;
  final offX = (size.x - anchoUsado) / 2, offY = (size.y - altoUsado) / 2;

  PdfPoint proyectar(RouteWaypoint w) => PdfPoint(
        offX + (w.lon - lonMin) * corrLon * escala,
        offY + (w.lat - latMin) * escala,
      );

  canvas.setStrokeColor(_pdfMapGrid);
  canvas.setLineWidth(0.4);
  for (var i = 1; i <= 3; i++) {
    final x = size.x * i / 4;
    canvas.moveTo(x, 0);
    canvas.lineTo(x, size.y);
  }
  for (var i = 1; i <= 3; i++) {
    final y = size.y * i / 4;
    canvas.moveTo(0, y);
    canvas.lineTo(size.x, y);
  }
  canvas.strokePath();

  if (dibujarLinea) {
    canvas.setStrokeColor(_pdfBlue);
    canvas.setLineWidth(1.3);
    final p0 = proyectar(wps.first);
    canvas.moveTo(p0.x, p0.y);
    for (final w in wps.skip(1)) {
      final p = proyectar(w);
      canvas.lineTo(p.x, p.y);
    }
    canvas.strokePath();
  }

  final ini = proyectar(wps.first);
  canvas.setColor(_pdfGood);
  canvas.drawEllipse(ini.x, ini.y, 2.2, 2.2);
  canvas.fillPath();

  final fin = proyectar(wps.last);
  final penultimo = wps.length >= 2 ? proyectar(wps[wps.length - 2]) : ini;
  var rumbo = math.atan2(fin.y - penultimo.y, fin.x - penultimo.x);
  if (fin.x == penultimo.x && fin.y == penultimo.y) rumbo = math.pi / 2;
  const largoFlecha = 4.5, anchoFlecha = 3.0;
  final puntaX = fin.x + math.cos(rumbo) * largoFlecha;
  final puntaY = fin.y + math.sin(rumbo) * largoFlecha;
  final baseAng1 = rumbo + math.pi * 0.75, baseAng2 = rumbo - math.pi * 0.75;
  final b1x = fin.x + math.cos(baseAng1) * anchoFlecha;
  final b1y = fin.y + math.sin(baseAng1) * anchoFlecha;
  final b2x = fin.x + math.cos(baseAng2) * anchoFlecha;
  final b2y = fin.y + math.sin(baseAng2) * anchoFlecha;
  canvas.setColor(_pdfOver);
  canvas.moveTo(puntaX, puntaY);
  canvas.lineTo(b1x, b1y);
  canvas.lineTo(b2x, b2y);
  canvas.lineTo(puntaX, puntaY);
  canvas.fillPath();

  if (escala > 0) {
    final metrosPorGrado = 111320.0;
    final pxPorMetro = escala / metrosPorGrado;
    final objetivoPx = size.x * 0.28;
    final candidatos = [50.0, 100.0, 200.0, 250.0, 500.0, 1000.0, 2000.0, 5000.0];
    var metrosBarra = candidatos.first;
    for (final m in candidatos) {
      if (m * pxPorMetro <= objetivoPx) metrosBarra = m;
    }
    final largoBarra = metrosBarra * pxPorMetro;
    final baseX = 4.0, baseY = 4.0;
    canvas.setStrokeColor(PdfColors.black);
    canvas.setLineWidth(1.0);
    canvas.moveTo(baseX, baseY);
    canvas.lineTo(baseX + largoBarra, baseY);
    canvas.strokePath();
  }
}
