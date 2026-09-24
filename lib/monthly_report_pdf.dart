// Informe mensual automatico (I1): PDF, storage y pantalla de informes.
//
// El calculo puro esta en monthly_report.dart; aqui va la IO: reunir los
// datos del mes (DailyStats + ChargeRebuild + costes, mismo criterio que el
// ticket de eficiencia), maquetar el PDF, guardarlo y exponer la pantalla
// donde verlo/compartirlo. La decision de CUANDO generar (primer ciclo de la
// semana del dia 1, una sola vez por mes) tambien es pura y vive alli.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'car_log_bridge.dart';
import 'charge_cost.dart';
import 'daily_stats.dart';
import 'energy_cost.dart' show EnergyPrice, preciosPorDia, totalizar;
import 'monthly_report.dart';
import 'pvpc.dart';

const _kInformeLast = 'lm_mes_report_last_v1';
const _store = FlutterSecureStorage();

Future<String?> informeUltimoGenerado() => _store.read(key: _kInformeLast);

Future<void> _marcarGenerado(String mesKey) =>
    _store.write(key: _kInformeLast, value: mesKey);

/// Carpeta donde viven los PDF de los informes, dentro de los documentos
/// de la app (sobrevive a reinicios y no se ve en la galeria).
Future<Directory> informesDir() async {
  final docs = await getApplicationDocumentsDirectory();
  final d = Directory('${docs.path}/informes');
  if (!await d.exists()) await d.create(recursive: true);
  return d;
}

/// true si en este ciclo toca generar el informe del mes anterior.
/// Pure decision + storage; el trabajo pesado solo ocurre cuando es true.
Future<bool> tocaGenerarInforme() async =>
    debeGenerarInforme(ahora: DateTime.now(), ultimoGenerado: await informeUltimoGenerado());

/// Datos mensuales con el mismo criterio que el ticket de eficiencia: los
/// precios efectivos por carga (manual > PVPC de la franja > precio fijo),
/// NUNCA inventados.
Future<DatosMes> _datosMes(String mesKey) async {
  final dias = await DailyStats.sync();
  final diasMes = dias.where((a) => a.d.startsWith(mesKey)).toList();
  final precios = await preciosPorDia();
  final tot = totalizar(diasMes, precios);

  final d0 = DateTime.parse('$mesKey-01');
  final d1 = DateTime(d0.year, d0.month + 1, 0); // ultimo dia del mes
  final todas = await ChargeRebuild.fromTrips();
  final cargas = todas.where((c) {
    final t = DateTime.fromMillisecondsSinceEpoch(c.endTs);
    return !DateTime(t.year, t.month, t.day).isBefore(d0) &&
        !DateTime(t.year, t.month, t.day).isAfter(d1);
  }).toList();

  // Coste por carga para el ranking barata/cara y como respaldo de euros.
  final costes = await ChargeCostStore.loadAll();
  final cfg = await EnergyPrice.load();
  final precioCasa = cfg?.eurKwh;
  final esPvpc = cfg?.esPvpc ?? false;
  var pagadoCargas = 0.0;
  var hayImporte = false;
  for (final c in cargas) {
    final m = costes[c.startTs];
    var precioEfectivo = precioCasa;
    var estimado = false;
    if (esPvpc && (m == null || (m.eur == null && m.eurKwh == null))) {
      final t = DateTime.fromMillisecondsSinceEpoch(c.endTs);
      final p = await Pvpc.precioFranja(
          DateTime.fromMillisecondsSinceEpoch(c.startTs), t);
      if (p != null) {
        precioEfectivo = p;
        estimado = true;
      }
    }
    final coste = costeCarga(
      kwhBateria: c.kwh,
      manual: m,
      precioCasa: precioEfectivo,
      marca: (e) => estimado = estimado || e,
    );
    if (coste != null) {
      pagadoCargas += coste;
      hayImporte = true;
    }
  }

  var kwhCarg = 0.0;
  for (final c in cargas) {
    kwhCarg += c.kwh;
  }

  return DatosMes(
    mesKey: mesKey,
    km: tot.km,
    kwhConsumidos: tot.kwh,
    kwhCargados: kwhCarg,
    euros: tot.hayEur ? tot.eur : (hayImporte ? pagadoCargas : 0),
    cargas: cargas.length,
  );
}

String _nombreMes(String mesKey) {
  const meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];
  final y = int.parse(mesKey.substring(0, 4));
  final m = int.parse(mesKey.substring(5, 7));
  return '${meses[m - 1]} $y';
}

String _d2(double v) => v.toStringAsFixed(2);
String _d1(double v) => v.toStringAsFixed(1);

String _pctTxt(double? p) => p == null
    ? '--'
    : '${p >= 0 ? '+' : ''}${p.toStringAsFixed(1)} %';

/// Genera el PDF del mes [mesKey]. Devuelve la ruta del fichero, o null si
/// el mes no tiene datos (no se genera un PDF vacio). Marca el mes como
/// informado SOLO si se genera.
Future<String?> generarInformeMes(String mesKey) async {
  final mes = await _datosMes(mesKey);
  if (mes.vacio) return null;
  final antKey = mesAnteriorKey(mesKey);
  final ant = await _datosMes(antKey);
  final termico = await Pvpc.termico();
  final resumen = computeResumenInforme(
    mes: mes,
    anterior: ant.vacio ? null : ant,
    litros100: termico.litros,
    precioLitro: termico.precio,
  );

  final doc = pw.Document();
  final h1 = pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold);
  final h2 = pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold);
  final peq = pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF666666));

  doc.addPage(
    pw.Page(
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('LMB10 - Informe mensual', style: h1),
          pw.SizedBox(height: 2),
          pw.Text(_nombreMes(mesKey).toUpperCase(),
              style: pw.TextStyle(fontSize: 14, color: PdfColor.fromInt(0xFF0D3B66))),
          pw.SizedBox(height: 2),
          pw.Text('Generado el ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} - datos locales de la app, sin servidor.',
              style: peq),
          pw.Divider(),
          pw.Text('RESUMEN DEL MES', style: h2),
          pw.SizedBox(height: 4),
          pw.Text('Distancia recorrida: ${mes.km.round()} km'),
          pw.Text('Energia consumida: ${_d1(mes.kwhConsumidos)} kWh'),
          if (resumen.consumo100km != null)
            pw.Text('Consumo medio: ${_d1(resumen.consumo100km!)} kWh/100 km'),
          pw.Text('Energia cargada: ${_d1(mes.kwhCargados)} kWh en ${mes.cargas} sesiones'),
          if (mes.euros > 0) ...[
            pw.Text('Coste electrico: ${_d2(mes.euros)} EUR'),
            if (resumen.coste100km != null)
              pw.Text('Coste por 100 km: ${_d2(resumen.coste100km!)} EUR'),
          ],
          if (resumen.co2EvitadoKg != null)
            pw.Text('CO2 evitado frente a termico: ${_d1(resumen.co2EvitadoKg!)} kg'),
          if (resumen.eurosAhorrados != null)
            pw.Text('Ahorro frente a gasolina: ${_d2(resumen.eurosAhorrados!)} EUR'),
          pw.SizedBox(height: 10),
          if (ant.vacio == false) ...[
            pw.Text('COMPARATIVA CON ${_nombreMes(antKey).toUpperCase()}', style: h2),
            pw.SizedBox(height: 4),
            pw.Text('Kilometros: ${_pctTxt(resumen.difKmPct)}'),
            if (resumen.difCoste100Pct != null)
              pw.Text('Coste/100 km: ${_pctTxt(resumen.difCoste100Pct)}'),
            if (mes.euros > 0 && ant.euros > 0)
              pw.Text('Gasto electrico: ${_pctTxt(resumen.difEurosPct)}'),
            pw.SizedBox(height: 10),
          ],
          pw.Text('NOTA', style: h2),
          pw.SizedBox(height: 4),
          pw.Text(
            'El coste usa el precio efectivo de cada carga (importe anotado, PVPC de la franja o precio fijo configurado). '
            'Los kWh consumidos se estiman desde la bateria: los trayectos que no pasan los filtros de credibilidad no cuentan para la media.',
            style: peq),
        ],
      ),
    ),
  );

  final bytes = await doc.save();
  final f = File('${(await informesDir()).path}/informe_$mesKey.pdf');
  await f.writeAsBytes(bytes);
  await _marcarGenerado(mesKey);
  await CarLogBridge.log('INFORME MENSUAL generado ' + f.path);
  return f.path;
}

/// Punto de entrada del ciclo de fondo: genera el informe del mes anterior
/// si toca y devuelve el titulo/listo para la notificacion, o null.
Future<String?> generarInformeSiToca() async {
  if (!await tocaGenerarInforme()) return null;
  final mesKey = mesAnteriorKey(mesKeyDe(DateTime.now()));
  try {
    final ruta = await generarInformeMes(mesKey);
    if (ruta == null) {
      // Mes sin datos: se marca igual para no reintentar toda la semana.
      await _marcarGenerado(mesKey);
      return null;
    }
    return _nombreMes(mesKey);
  } catch (e) {
    await CarLogBridge.log('INFORME MENSUAL FALLO: ' + e.toString());
    return null;
  }
}

/// Pantalla de Ajustes: lista los informes generados con opcion de
/// compartirlos y de generar el del mes pasado a mano.
class InformesScreen extends StatefulWidget {
  const InformesScreen({super.key});
  @override
  State<InformesScreen> createState() => _InformesScreenState();
}

class _InformesScreenState extends State<InformesScreen> {
  List<File> _files = [];
  bool _generando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final d = await informesDir();
    final fs = await d
        .list()
        .where((e) => e is File && e.path.endsWith('.pdf'))
        .cast<File>()
        .toList();
    fs.sort((a, b) => b.path.compareTo(a.path));
    if (mounted) setState(() => _files = fs);
  }

  Future<void> _generar() async {
    setState(() => _generando = true);
    final mesKey = mesAnteriorKey(mesKeyDe(DateTime.now()));
    final ruta = await generarInformeMes(mesKey);
    if (!mounted) return;
    setState(() => _generando = false);
    if (ruta == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('El mes pasado no tiene datos registrados.')));
      return;
    }
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    return Scaffold(
      appBar: AppBar(title: Text(es ? 'Informes mensuales' : 'Monthly reports')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: OutlinedButton.icon(
              icon: _generando
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.picture_as_pdf_outlined),
              label: Text(es ? 'Generar informe del mes pasado' : 'Generate last month report'),
              onPressed: _generando ? null : _generar,
            ),
          ),
          Expanded(
            child: _files.isEmpty
                ? Center(
                    child: Text(es
                        ? 'Todavia no hay informes. El dia 1 de cada mes se genera automaticamente el del mes anterior.'
                        : 'No reports yet. On the 1st of each month the previous month report is generated automatically.'))
                : ListView.builder(
                    itemCount: _files.length,
                    itemBuilder: (_, i) {
                      final f = _files[i];
                      final nombre = f.uri.pathSegments.last;
                      return ListTile(
                        leading: const Icon(Icons.picture_as_pdf),
                        title: Text(nombre),
                        subtitle: Text(es ? 'Toca el icono para compartir' : 'Tap the icon to share'),
                        trailing: IconButton(
                          icon: const Icon(Icons.share),
                          onPressed: () => SharePlus.instance.share(
                              ShareParams(files: [XFile(f.path)])),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
