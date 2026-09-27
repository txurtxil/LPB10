// informe_consumo_screen.dart — Informe de consumo profesional (v3.60.200).
// Ventana deslizante de hasta 30 dias con dato de consumo: barras diarias de
// kWh/100 km, coste en euros (precio del dia), consumo por bandas de
// temperatura exterior (Open-Meteo) y comparativa con la ventana anterior.
// Exportable a PDF y compartible. Todo se calcula del historico local
// (trips.jsonl + agregado diario + precios); no toca la nube del coche.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'daily_stats.dart';
import 'energy_cost.dart' show preciosPorDia;
import 'history_archive.dart';
import 'widget_chart.dart' show gBatteryKwh;

class _DiaConsumo {
  final String d; // yyyy-MM-dd
  final double km;
  final double kwh100;
  final double coste;
  final double? te;
  const _DiaConsumo(this.d, this.km, this.kwh100, this.coste, this.te);
}

class InformeConsumoScreen extends StatefulWidget {
  const InformeConsumoScreen({super.key});
  @override
  State<InformeConsumoScreen> createState() => _InformeConsumoScreenState();
}

class _InformeConsumoScreenState extends State<InformeConsumoScreen> {
  bool _cargando = true;
  bool _exportando = false;
  List<_DiaConsumo> _dias = [];
  List<_DiaConsumo> _prev = [];
  double _varPct = 0;
  bool _hayPrev = false;

  static String _2(int n) => n.toString().padLeft(2, '0');

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final agg = await DailyStats.load();
    final precios = await preciosPorDia();
    // Temperatura exterior media por dia, parseando trips.jsonl (el loader
    // compartido de salud no devuelve 'te'; aqui hace falta).
    final teDia = <String, List<double>>{};
    try {
      final dir = await HistoryArchive.dir();
      final f = File('${dir.path}/trips.jsonl');
      if (await f.exists()) {
        for (final line in await f.readAsLines()) {
          try {
            final m = json.decode(line);
            if (m is! Map) continue;
            final te = (m['te'] as num?)?.toDouble();
            final ts = m['ts'];
            if (te == null || ts is! int) continue;
            final dia = DateTime.fromMillisecondsSinceEpoch(ts);
            final key = '${dia.year}-${_2(dia.month)}-${_2(dia.day)}';
            (teDia[key] ??= []).add(te);
          } catch (_) {}
        }
      }
    } catch (_) {}
    final todos = <_DiaConsumo>[];
    for (final a in agg) {
      if (a.d.length != 10) continue; // solo dias reales, no rollups
      if (a.km < DailyStats.kMinKm) continue;
      final pct = a.soc / a.km * 100.0;
      if (pct < DailyStats.kMinAvg || pct > DailyStats.kMaxAvg) continue;
      final kwh100 = pct / 100.0 * gBatteryKwh;
      final kwhDia = a.soc / 100.0 * gBatteryKwh;
      final coste = (precios[a.d] ?? 0.0) * kwhDia;
      final tes = teDia[a.d];
      final te = (tes == null || tes.isEmpty)
          ? null
          : tes.reduce((x, y) => x + y) / tes.length;
      todos.add(_DiaConsumo(a.d, a.km, kwh100, coste, te));
    }
    if (!mounted) return;
    if (todos.length < 4) {
      setState(() => _cargando = false);
      return;
    }
    final n = todos.length >= 30 ? 30 : (todos.length ~/ 2);
    final actuales = todos.sublist(todos.length - n);
    final anteriores = todos.sublist(0, todos.length - n);
    final prev = anteriores.length >= n
        ? anteriores.sublist(anteriores.length - n)
        : anteriores;
    final mediaA = actuales.map((e) => e.kwh100).reduce((a, b) => a + b) / actuales.length;
    double varPct = 0;
    var hayPrev = false;
    if (prev.isNotEmpty) {
      final mediaP = prev.map((e) => e.kwh100).reduce((a, b) => a + b) / prev.length;
      if (mediaP > 0) {
        varPct = (mediaA - mediaP) / mediaP * 100.0;
        hayPrev = true;
      }
    }
    setState(() {
      _dias = actuales;
      _prev = prev;
      _varPct = varPct;
      _hayPrev = hayPrev;
      _cargando = false;
    });
  }

  double get _kmTotal => _dias.fold(0.0, (a, b) => a + b.km);
  double get _costeTotal => _dias.fold(0.0, (a, b) => a + b.coste);
  double get _media100 =>
      _dias.fold(0.0, (a, b) => a + b.kwh100) / _dias.length;
  double get _eur100 => _kmTotal > 0 ? _costeTotal / _kmTotal * 100.0 : 0.0;

  /// Consumo medio por banda de temperatura exterior.
  Map<String, double> _bandas() {
    final acc = <String, List<double>>{};
    for (final d in _dias) {
      if (d.te == null) continue;
      final b = d.te! < 5
          ? '<5'
          : d.te! < 15
              ? '5-15'
              : d.te! < 25
                  ? '15-25'
                  : '25+';
      (acc[b] ??= []).add(d.kwh100);
    }
    final out = <String, double>{};
    acc.forEach((k, v) => out[k] = v.reduce((a, b) => a + b) / v.length);
    return out;
  }

  Future<void> _exportarPdf() async {
    final es = Localizations.localeOf(context).languageCode == 'es';
    setState(() => _exportando = true);
    try {
      final doc = pw.Document();
      final bandas = _bandas();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(es ? 'Informe de consumo' : 'Consumption report',
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('${_dias.first.d} -> ${_dias.last.d}   '
                  'LMB10 v3.60.200'),
              pw.SizedBox(height: 12),
              pw.Text(es
                  ? 'Km: ${_kmTotal.toStringAsFixed(0)}   Media: ${_media100.toStringAsFixed(1)} kWh/100km   Coste: ${_costeTotal.toStringAsFixed(2)} EUR   ${_eur100.toStringAsFixed(2)} EUR/100km'
                  : 'Km: ${_kmTotal.toStringAsFixed(0)}   Avg: ${_media100.toStringAsFixed(1)} kWh/100km   Cost: ${_costeTotal.toStringAsFixed(2)} EUR   ${_eur100.toStringAsFixed(2)} EUR/100km'),
              if (_hayPrev)
                pw.Text(es
                    ? 'Variacion vs periodo anterior: ${_varPct.toStringAsFixed(1)} %'
                    : 'Change vs previous period: ${_varPct.toStringAsFixed(1)} %'),
              pw.SizedBox(height: 12),
              pw.TableHelper.fromTextArray(
                headers: es
                    ? ['Fecha', 'km', 'kWh/100km', 'EUR']
                    : ['Date', 'km', 'kWh/100km', 'EUR'],
                data: [
                  for (final d in _dias)
                    [d.d, d.km.toStringAsFixed(0),
                     d.kwh100.toStringAsFixed(1),
                     d.coste.toStringAsFixed(2)]
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Text(es
                  ? 'Consumo segun temperatura exterior:'
                  : 'Consumption by outdoor temperature:'),
              for (final b in ['<5', '5-15', '15-25', '25+'])
                if (bandas.containsKey(b))
                  pw.Text('$b C:  ${bandas[b]!.toStringAsFixed(1)} kWh/100km'),
              pw.SizedBox(height: 12),
              pw.Text(
                es
                    ? 'Consumo estimado desde el SoC del coche; el coste usa el precio de cada dia (PVPC o tarifa).'
                    : 'Estimated consumption from car SoC; cost uses each day price (PVPC or tariff).',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],
          ),
        ),
      );
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/informe_consumo_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await f.writeAsBytes(await doc.save());
      await Share.shareXFiles([XFile(f.path)],
          text: es ? 'Informe de consumo LMB10' : 'LMB10 consumption report');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(es ? 'No se pudo generar el PDF' : 'Could not generate the PDF')));
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    return Scaffold(
      appBar: AppBar(
        title: Text(es ? 'Informe de consumo' : 'Consumption report'),
        actions: [
          IconButton(
            tooltip: es ? 'Exportar PDF' : 'Export PDF',
            icon: _exportando
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _exportando || _dias.isEmpty ? null : _exportarPdf,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _dias.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(es
                        ? 'Aun no hay dias suficientes con datos de consumo. Conduce unos dias y vuelve.'
                        : 'Not enough days with consumption data yet. Drive for a few days and come back.'),
                  ),
                )
              : ListView(
                  padding: EdgeInsets.fromLTRB(
                      16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
                  children: [
                    _resumen(es),
                    const SizedBox(height: 12),
                    Text(es ? 'Consumo diario (kWh/100 km)' : 'Daily consumption (kWh/100 km)',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 150,
                      child: CustomPaint(
                        painter: _BarrasConsumo(_dias,
                            Theme.of(context).colorScheme.primary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(es ? 'Segun temperatura exterior' : 'By outdoor temperature',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    _tablaBandas(es),
                    const SizedBox(height: 8),
                    Text(
                      es
                          ? 'Consumo estimado desde el SoC del coche. Coste con el precio de cada dia.'
                          : 'Estimated consumption from car SoC. Cost uses each day price.',
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                    ),
                  ],
                ),
    );
  }

  Widget _resumen(bool es) {
    final color = !_hayPrev
        ? Colors.grey
        : _varPct <= 0
            ? const Color(0xFF2A9D8F)
            : const Color(0xFFE76F51);
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFFBFE0FA),
          borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(es ? 'Resumen del periodo' : 'Period summary',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D3B66))),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _dato(es ? 'Km' : 'Km', _kmTotal.toStringAsFixed(0)),
            _dato(es ? 'Media' : 'Avg', '${_media100.toStringAsFixed(1)} kWh/100'),
            _dato('EUR', _costeTotal.toStringAsFixed(2)),
          ]),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _dato(es ? 'EUR/100km' : 'EUR/100km', _eur100.toStringAsFixed(2)),
            if (_hayPrev)
              _dato(es ? 'Vs anterior' : 'Vs previous',
                  '${_varPct >= 0 ? "+" : ""}${_varPct.toStringAsFixed(1)} %',
                  color: color),
          ]),
          if (_hayPrev) ...[
            const SizedBox(height: 6),
            Text(
              es
                  ? (_varPct <= 0
                      ? 'Consumes un ${_varPct.abs().toStringAsFixed(1)} % menos que en la ventana anterior.'
                      : 'Consumes un ${_varPct.toStringAsFixed(1)} % mas que en la ventana anterior.')
                  : (_varPct <= 0
                      ? 'You consume ${_varPct.abs().toStringAsFixed(1)} % less than the previous window.'
                      : 'You consume ${_varPct.toStringAsFixed(1)} % more than the previous window.'),
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dato(String etiqueta, String valor, {Color? color}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF0D3B66))),
          Text(valor,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color ?? const Color(0xFF0D3B66))),
        ],
      );

  Widget _tablaBandas(bool es) {
    final bandas = _bandas();
    const orden = ['<5', '5-15', '15-25', '25+'];
    if (bandas.isEmpty) {
      return Text(es
          ? 'Sin datos de temperatura exterior en este periodo.'
          : 'No outdoor temperature data in this period.');
    }
    return Column(
      children: [
        for (final b in orden)
          if (bandas.containsKey(b))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                      width: 70,
                      child: Text('$b C',
                          style: const TextStyle(
                              fontFamily: 'monospace'))),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (bandas[b]! / 30.0).clamp(0.0, 1.0).toDouble(),
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${bandas[b]!.toStringAsFixed(1)} kWh/100',
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12)),
                ],
              ),
            ),
      ],
    );
  }
}

/// Barras diarias de consumo con marcas de fecha cada 5 dias.
class _BarrasConsumo extends CustomPainter {
  final List<_DiaConsumo> dias;
  final Color color;
  _BarrasConsumo(this.dias, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (dias.isEmpty) return;
    final maxV = dias.fold<double>(0, (a, b) => b.kwh100 > a ? b.kwh100 : a);
    if (maxV <= 0) return;
    final base = size.height - 16;
    final ancho = size.width / dias.length;
    final paint = Paint()..color = color;
    final linea = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, base), Offset(size.width, base), linea);
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < dias.length; i++) {
      final h = (base - 4) * (dias[i].kwh100 / maxV);
      canvas.drawRect(
        Rect.fromLTWH(i * ancho + 2, base - h, ancho - 4, h),
        paint,
      );
      if (i % 5 == 0 || i == dias.length - 1) {
        tp.text = TextSpan(
            text: dias[i].d.substring(8),
            style: TextStyle(fontSize: 9, color: Colors.grey.shade600));
        tp.layout();
        tp.paint(canvas, Offset(i * ancho, base + 2));
      }
    }
  }

  @override
  bool shouldRepaint(_BarrasConsumo old) => old.dias != dias;
}
