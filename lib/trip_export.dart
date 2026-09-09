// trip_export.dart
//
// Exporta el historico de rutas a un PDF: portada con totales del periodo,
// y una tarjeta compacta por ruta con su trazado, km, consumo y coste
// estimado segun el precio configurado ese dia.
//
// El trazado se dibuja como esquema vectorial propio, NO como mapa real:
// evita depender de un proveedor de mosaicos externo (CARTO empezo a exigir
// clave en 08/2026, ver route_map_screen.dart) y funciona sin conexion,
// instantaneo, con los mismos puntos GPS que ya se tienen guardados.
//
// AVISO DE HONESTIDAD (06/09/2026, se deja escrito a proposito): el dibujo
// del trazado usa el canvas de bajo nivel del paquete pdf (PdfGraphics), que
// no se ha podido compilar ni probar antes de entregar este fichero. Es
// razonablemente probable que algun nombre de metodo no coincida exacto con
// la version de 'pdf' instalada. Si flutter analyze/build se queja aqui, no
// es un fallo de diseno, es la API de dibujo sin verificar contra el
// compilador real.
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
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
            ? 'Vas a exportar ${rutas.length} rutas. El PDF puede tardar unos segundos en generarse.'
            : 'You are about to export ${rutas.length} trips. The PDF may take a few seconds to generate.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(es ? 'Cancelar' : 'Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(es ? 'Continuar' : 'Continue')),
        ],
      ),
    );
    if (continuar != true || !context.mounted) return;
  }

  final precios = await preciosPorDia();
  final doc = pw.Document();

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
    final grupo = rutas.sublist(i, math.min(i + porPagina, rutas.length));
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pwCtx) => pw.GridView(
        crossAxisCount: 2,
        childAspectRatio: 1.35,
        children: [for (final r in grupo) _rutaCard(r, precios, es)],
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

pw.Widget _rutaCard(RouteTrip r, Map<String, double> precios, bool es) {
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
        pw.Expanded(
          child: r.hasGps
              ? pw.ClipRect(
                  child: pw.CustomPaint(
                    painter: (canvas, size) => _dibujarTrazado(canvas, size, r.waypoints),
                  ),
                )
              : pw.Center(
                  child: pw.Text(
                    r.reconstruida
                        ? (es ? 'Sin recorrido\n(sondeo interrumpido)' : 'No path\n(polling interrupted)')
                        : (es ? 'Sin datos GPS' : 'No GPS data'),
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: 8, color: _pdfGrey, fontStyle: pw.FontStyle.italic),
                  ),
                ),
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

/// Esquema vectorial del trazado: proyeccion equirectangular simple
/// (corrige la distorsion de longitud multiplicando por cos(lat)), escalada
/// para llenar el lienzo disponible manteniendo la proporcion real. No es
/// un mapa: no hay calles ni referencias, solo la forma del recorrido.
void _dibujarTrazado(PdfGraphics canvas, PdfPoint size, List<RouteWaypoint> wps) {
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

  canvas.setStrokeColor(_pdfBlue);
  canvas.setLineWidth(1.3);
  final p0 = proyectar(wps.first);
  canvas.moveTo(p0.x, p0.y);
  for (final w in wps.skip(1)) {
    final p = proyectar(w);
    canvas.lineTo(p.x, p.y);
  }
  canvas.strokePath();

  final ini = proyectar(wps.first);
  canvas.setColor(_pdfGood);
  canvas.drawEllipse(ini.x, ini.y, 2.2, 2.2);
  canvas.fillPath();

  final fin = proyectar(wps.last);
  canvas.setColor(_pdfOver);
  canvas.drawEllipse(fin.x, fin.y, 2.6, 2.6);
  canvas.fillPath();
}
