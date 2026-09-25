// Informes PDF de bateria (mas alla de LeapMotor Mate): informe de salud
// (capacidad estimada, cargas medidas, descarga pasiva, consumo por
// temperatura) y listado de costes de carga. Generados 100% en local con
// el historico de la app y compartibles por el menu habitual del movil.

import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'battery_health.dart';
import 'charging_costs.dart';
import 'consumption_temp.dart';
import 'monthly_report_pdf.dart' show informesDir;
import 'widget_chart.dart' show gBatteryKwh;

final _h1 = pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold);
final _h2 = pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold);
final _peq = pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFF666666));
final _azul = PdfColor.fromInt(0xFF0D3B66);

String _fecha(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  String two(int x) => x.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year}';
}

String _stamp() {
  final n = DateTime.now();
  String two(int x) => x.toString().padLeft(2, '0');
  return '${n.year}${two(n.month)}${two(n.day)}';
}

pw.Widget _cabecera(String titulo) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('LMB10 - $titulo', style: _h1),
        pw.SizedBox(height: 2),
        pw.Text(
            'Generado el ${_fecha(DateTime.now().millisecondsSinceEpoch)} - calculado en el movil, sin servidor.',
            style: _peq),
        pw.Divider(),
      ],
    );

pw.Widget _tabla(List<String> cab, List<List<String>> filas) => pw.Table(
      border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFCCCCCC), width: 0.5),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _azul),
          children: [
            for (final c in cab)
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(c,
                    style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white)),
              ),
          ],
        ),
        for (final f in filas)
          pw.TableRow(
            children: [
              for (final c in f)
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(c, style: const pw.TextStyle(fontSize: 8)),
                ),
            ],
          ),
      ],
    );

/// Informe de salud de la bateria: capacidad estimada y su % frente a la
/// referencia de fabrica, tabla de cargas medidas, descarga pasiva y
/// consumo por bandas de temperatura.
Future<File> informeSaludPdf(ResumenSalud salud, ResumenDescarga desc,
    List<PuntoConsumo> puntos) async {
  final doc = pw.Document();
  final cap = salud.capacidadKwh;
  final bandas = consumoPorBanda(puntos);

  doc.addPage(
    pw.MultiPage(
      build: (ctx) => [
        _cabecera('Informe de salud de la bateria'),
        pw.Text('CAPACIDAD ESTIMADA', style: _h2),
        pw.SizedBox(height: 4),
        if (cap == null)
          pw.Text('Todavia no hay cargas medidas suficientes para estimar la capacidad.')
        else ...[
          pw.Text(
              'Capacidad util estimada: ${cap.toStringAsFixed(1)} kWh '
              '(${(cap / gBatteryKwh * 100).toStringAsFixed(1)} % de la referencia de nuevo, ${gBatteryKwh.toStringAsFixed(1)} kWh)'),
          pw.Text(
              'Dispersion entre cargas: ±${salud.dispersionPct?.toStringAsFixed(1) ?? '--'} % · '
              '${salud.numEstimaciones} cargas medidas'
              '${salud.excluidasFrio > 0 ? ' (${salud.excluidasFrio} con bateria fria, fuera del computo)' : ''}'),
        ],
        pw.SizedBox(height: 10),
        if (salud.estimaciones.isNotEmpty) ...[
          pw.Text('CARGAS MEDIDAS', style: _h2),
          pw.SizedBox(height: 4),
          _tabla(
            ['Fecha', 'SoC', 'Energia', 'Capacidad', 'Temp min', 'Nota'],
            [
              for (final e in salud.estimaciones.reversed.take(30))
                [
                  _fecha(e.finMs),
                  '${e.socIni.toStringAsFixed(0)}>${e.socFin.toStringAsFixed(0)} %',
                  '${e.energiaKwh.toStringAsFixed(1)} kWh',
                  '${e.capacidadKwh.toStringAsFixed(1)} kWh',
                  e.tempMin == null ? '--' : '${e.tempMin!.toStringAsFixed(0)} C',
                  e.excluida ? 'fria (excluida)' : '',
                ],
            ],
          ),
          pw.SizedBox(height: 10),
        ],
        pw.Text('DESCARGA PASIVA', style: _h2),
        pw.SizedBox(height: 4),
        if (desc.pctDia == null)
          pw.Text('Sin paradas suficientes registradas.')
        else
          pw.Text(
              '${desc.pctDia!.toStringAsFixed(2)} %/dia (perdida total ${desc.perdidaTotalPct.toStringAsFixed(1)} % en ${desc.horasTotales.toStringAsFixed(0)} h aparcado, ${desc.numParadas} paradas)'),
        pw.SizedBox(height: 10),
        pw.Text('CONSUMO SEGUN TEMPERATURA', style: _h2),
        pw.SizedBox(height: 4),
        if (puntos.isEmpty)
          pw.Text('Sin tramos con temperatura registrados todavia.')
        else ...[
          pw.Text('${puntos.length} tramos de conduccion analizados (% de bateria por 100 km):'),
          pw.SizedBox(height: 4),
          _tabla(
            ['Temperatura', '<5 C', '5-15 C', '15-25 C', '25+ C'],
            [
              [
                'Consumo medio',
                for (final b in kBandasTemp)
                  bandas[b] == null ? '--' : '${bandas[b]!.toStringAsFixed(1)} %/100km',
              ],
            ],
          ),
        ],
        pw.SizedBox(height: 10),
        pw.Text('METODO', style: _h2),
        pw.SizedBox(height: 4),
        pw.Text(
            'La capacidad se estima con la energia medida de cada carga (integral de tension x corriente) dividida por el SoC ganado, capado al 95 %. '
            'Solo cuentan cargas con corriente >= 2 A y las de paquete frio (<15 C) quedan fuera de la cifra. '
            'Es una estimacion, no una medicion de laboratorio.',
            style: _peq),
      ],
    ),
  );

  final f = File('${(await informesDir()).path}/salud_bateria_${_stamp()}.pdf');
  await f.writeAsBytes(await doc.save());
  return f;
}

/// Listado de costes de carga: tarifas, tabla de sesiones y totales por
/// mes. La energia es la que entra al paquete (la de red es algo mayor).
Future<File> listadoCostesPdf(List<SesionCarga> sesiones,
    Map<String, MesCarga> meses, Tarifas tarifas) async {
  final doc = pw.Document();
  String tarifa(double? t) => t == null ? '--' : '${t.toStringAsFixed(3)} EUR/kWh';
  String tipo(TipoCarga t) => t == TipoCarga.ac ? 'AC' : (t == TipoCarga.dc ? 'DC' : 'HPC');

  final clavesMes = meses.keys.toList()..sort();

  doc.addPage(
    pw.MultiPage(
      build: (ctx) => [
        _cabecera('Listado de costes de carga'),
        pw.Text('TARIFAS', style: _h2),
        pw.SizedBox(height: 4),
        pw.Text(
            'AC: ${tarifa(tarifas.ac)} · DC: ${tarifa(tarifas.dc)} · HPC: ${tarifa(tarifas.hpc)} '
            '(AC <= 11 kW, DC hasta 100 kW, HPC por encima)'),
        pw.SizedBox(height: 10),
        pw.Text('TOTALES POR MES', style: _h2),
        pw.SizedBox(height: 4),
        if (clavesMes.isEmpty)
          pw.Text('Sin sesiones de carga registradas.')
        else
          _tabla(
            ['Mes', 'Sesiones', 'AC kWh', 'DC kWh', 'HPC kWh', 'Coste'],
            [
              for (final k in clavesMes.reversed)
                [
                  k,
                  '${meses[k]!.sesiones}',
                  meses[k]!.kwhAc.toStringAsFixed(1),
                  meses[k]!.kwhDc.toStringAsFixed(1),
                  meses[k]!.kwhHpc.toStringAsFixed(1),
                  meses[k]!.coste == null
                      ? '--'
                      : '${meses[k]!.coste!.toStringAsFixed(2)} EUR',
                ],
            ],
          ),
        pw.SizedBox(height: 10),
        pw.Text('SESIONES (ULTIMAS 60)', style: _h2),
        pw.SizedBox(height: 4),
        if (sesiones.isEmpty)
          pw.Text('Sin sesiones.')
        else
          _tabla(
            ['Fecha', 'Tipo', 'Energia', 'Pico', 'SoC', 'Coste'],
            [
              for (final s in sesiones.reversed.take(60))
                [
                  _fecha(s.iniMs),
                  tipo(s.tipo),
                  '${s.energiaKwh.toStringAsFixed(1)} kWh',
                  '${s.potMaxKw.toStringAsFixed(0)} kW',
                  '${s.socIni.toStringAsFixed(0)}>${s.socFin.toStringAsFixed(0)} %',
                  costeSesion(s, tarifas) == null
                      ? '--'
                      : '${costeSesion(s, tarifas)!.toStringAsFixed(2)} EUR',
                ],
            ],
          ),
        pw.SizedBox(height: 10),
        pw.Text(
            'La energia es la que entra al paquete segun la telemetria del coche; la que factura el cargador es algo mayor por las perdidas de conversion.',
            style: _peq),
      ],
    ),
  );

  final f = File('${(await informesDir()).path}/costes_carga_${_stamp()}.pdf');
  await f.writeAsBytes(await doc.save());
  return f;
}

/// Abre la hoja de compartir del sistema con el PDF generado.
Future<void> compartirPdf(File f) async {
  await Share.shareXFiles([XFile(f.path)],
      subject: f.uri.pathSegments.last);
}
