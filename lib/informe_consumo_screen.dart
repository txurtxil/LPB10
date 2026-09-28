// informe_consumo_screen.dart — Informe de consumo profesional (v3.60.201).
// UNICA puerta de analitica de consumo: selector de periodo (7d / 30d /
// TODO el historico / rango libre), resumen a color (km, kWh/100km, euros,
// objetivo del catalogo, mejor/peor dia, variacion vs ventana anterior),
// grafica de barras, consumo por bandas de temperatura exterior y PDF a
// todo color imprimible y enviable. El recibo de impresora termica sigue
// disponible con el mismo rango desde el boton "Ticket termico".
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'daily_stats.dart';
import 'energy_cost.dart' show preciosPorDia;
import 'history_archive.dart';
import 'ticket_screen.dart';
import 'widget_chart.dart' show gBatteryKwh, gMaxRangeKm;

class _DiaConsumo {
  final String d; // yyyy-MM-dd
  final double km;
  final double kwh100;
  final double coste;
  final double? te;
  const _DiaConsumo(this.d, this.km, this.kwh100, this.coste, this.te);
}

enum _Per { s7, s30, todo, rango }

class InformeConsumoScreen extends StatefulWidget {
  const InformeConsumoScreen({super.key});
  @override
  State<InformeConsumoScreen> createState() => _InformeConsumoScreenState();
}

class _InformeConsumoScreenState extends State<InformeConsumoScreen> {
  bool _cargando = true;
  bool _exportando = false;
  _Per _per = _Per.todo;
  DateTimeRange? _rango;
  List<_DiaConsumo> _todos = [];
  List<_DiaConsumo> _dias = [];
  List<_DiaConsumo> _prev = [];

  static String _2(int n) => n.toString().padLeft(2, '0');

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final agg = await DailyStats.load();
    final precios = await preciosPorDia();
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
      if (a.d.length != 10) continue;
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
    setState(() {
      _todos = todos;
      _cargando = false;
    });
    _aplicarPeriodo();
  }

  void _aplicarPeriodo() {
    if (_todos.isEmpty) {
      setState(() { _dias = []; _prev = []; });
      return;
    }
    List<_DiaConsumo> act;
    List<_DiaConsumo> prev = [];
    if (_per == _Per.todo) {
      act = List.of(_todos);
    } else if (_per == _Per.rango) {
      if (_rango == null) {
        _elegirRango();
        return;
      }
      final ini = _rango!.start.toIso8601String().substring(0, 10);
      final fin = _rango!.end.toIso8601String().substring(0, 10);
      act = _todos.where((d) => d.d.compareTo(ini) >= 0 && d.d.compareTo(fin) <= 0).toList();
      final n = act.length;
      if (n > 0) {
        final antes = _todos.where((d) => d.d.compareTo(ini) < 0).toList();
        prev = antes.length >= n
            ? antes.sublist(antes.length - n)
            : antes;
      }
    } else {
      final n = _per == _Per.s7 ? 7 : 30;
      if (_todos.length <= n) {
        act = List.of(_todos);
      } else {
        act = _todos.sublist(_todos.length - n);
        final antes = _todos.sublist(0, _todos.length - n);
        prev = antes.length >= n ? antes.sublist(antes.length - n) : antes;
      }
    }
    setState(() {
      _dias = act;
      _prev = prev;
    });
  }

  Future<void> _elegirRango() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
    );
    if (r == null) return;
    setState(() {
      _per = _Per.rango;
      _rango = r;
    });
    _aplicarPeriodo();
  }

  double get _kmTotal => _dias.fold(0.0, (a, b) => a + b.km);
  double get _costeTotal => _dias.fold(0.0, (a, b) => a + b.coste);
  double get _media100 =>
      _dias.isEmpty ? 0 : _dias.fold(0.0, (a, b) => a + b.kwh100) / _dias.length;
  double get _eur100 => _kmTotal > 0 ? _costeTotal / _kmTotal * 100.0 : 0.0;
  double get _objetivo =>
      gMaxRangeKm > 0 ? gBatteryKwh / gMaxRangeKm * 100.0 : 15.6;

  bool get _hayPrev => _prev.isNotEmpty && _per != _Per.todo;
  double get _varPct {
    if (!_hayPrev) return 0;
    final p = _prev.fold(0.0, (a, b) => a + b.kwh100) / _prev.length;
    if (p <= 0) return 0;
    return (_media100 - p) / p * 100.0;
  }

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

  _DiaConsumo? get _mejor {
    if (_dias.isEmpty) return null;
    var m = _dias.first;
    for (final d in _dias) { if (d.kwh100 < m.kwh100) m = d; }
    return m;
  }
  _DiaConsumo? get _peor {
    if (_dias.isEmpty) return null;
    var m = _dias.first;
    for (final d in _dias) { if (d.kwh100 > m.kwh100) m = d; }
    return m;
  }

  static String _fecha(String iso) => '${iso.substring(8)}/${iso.substring(5, 7)}';

  Future<void> _exportarPdf() async {
    final es = Localizations.localeOf(context).languageCode == 'es';
    if (_dias.isEmpty) return;
    setState(() => _exportando = true);
    try {
      final doc = pw.Document();
      final bandas = _bandas();
      final maxV = _dias.fold<double>(0, (a, b) => b.kwh100 > a ? b.kwh100 : a);
      final vis = _dias.length > 31 ? _dias.sublist(_dias.length - 31) : _dias;
      final obj = _objetivo;
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text(es ? 'Informe de consumo' : 'Consumption report',
                    style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.Text('LMB10', style: pw.TextStyle(fontSize: 12, color: PdfColors.blue700)),
              ]),
              pw.SizedBox(height: 4),
              pw.Text('${_dias.first.d} -> ${_dias.last.d}  (${_dias.length} ' +
                  (es ? 'dias' : 'days') + ')',
                  style: const pw.TextStyle(color: PdfColors.grey700)),
              pw.SizedBox(height: 12),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    borderRadius: pw.BorderRadius.circular(8)),
                child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      _pdfDato(es ? 'Km' : 'Km', _kmTotal.toStringAsFixed(0)),
                      _pdfDato(es ? 'Media' : 'Avg', '${_media100.toStringAsFixed(1)} kWh/100'),
                      _pdfDato('EUR', _costeTotal.toStringAsFixed(2)),
                      _pdfDato(es ? 'EUR/100km' : 'EUR/100km', _eur100.toStringAsFixed(2)),
                      _pdfDato(es ? 'Objetivo' : 'Target', '${obj.toStringAsFixed(1)}'),
                    ]),
              ),
              pw.SizedBox(height: 10),
              pw.Text(es ? 'Consumo diario (ultimos ${vis.length} dias), kWh/100km' :
                             'Daily consumption (last ${vis.length} days), kWh/100km'),
              pw.SizedBox(height: 4),
              pw.Container(
                height: 90,
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    for (final d in vis)
                      pw.Expanded(
                        child: pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 1),
                          child: pw.Container(
                            height: maxV > 0 ? math.max(2.0, 86.0 * d.kwh100 / maxV) : 2.0,
                            color: PdfColors.blue400,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              if (_hayPrev)
                pw.Text(es
                    ? 'Variacion vs ventana anterior (${_prev.length} dias): ${_varPct.toStringAsFixed(1)} %'
                    : 'Change vs previous window (${_prev.length} days): ${_varPct.toStringAsFixed(1)} %'),
              if (_mejor != null)
                pw.Text(es
                    ? 'Mejor dia: ${_fecha(_mejor!.d)} (${_mejor!.kwh100.toStringAsFixed(1)})   Peor dia: ${_fecha(_peor!.d)} (${_peor!.kwh100.toStringAsFixed(1)}) kWh/100km'
                    : 'Best day: ${_fecha(_mejor!.d)} (${_mejor!.kwh100.toStringAsFixed(1)})   Worst day: ${_fecha(_peor!.d)} (${_peor!.kwh100.toStringAsFixed(1)})'),
              pw.SizedBox(height: 10),
              if (_dias.length <= 31)
                pw.TableHelper.fromTextArray(
                  headers: es
                      ? ['Fecha', 'km', 'kWh/100km', 'EUR']
                      : ['Date', 'km', 'kWh/100km', 'EUR'],
                  data: [
                    for (final d in _dias)
                      [_fecha(d.d), d.km.toStringAsFixed(0),
                       d.kwh100.toStringAsFixed(1), d.coste.toStringAsFixed(2)]
                  ],
                )
              else ...[
                pw.Text(es ? 'Resumen mensual:' : 'Monthly summary:'),
                pw.TableHelper.fromTextArray(
                  headers: es
                      ? ['Mes', 'km', 'kWh/100km', 'EUR']
                      : ['Month', 'km', 'kWh/100km', 'EUR'],
                  data: _mensual()
                      .map((m) => [m[0], m[1], m[2], m[3]])
                      .toList(),
                ),
              ],
              pw.SizedBox(height: 10),
              pw.Text(es ? 'Consumo segun temperatura exterior:' :
                             'Consumption by outdoor temperature:'),
              for (final b in ['<5', '5-15', '15-25', '25+'])
                if (bandas.containsKey(b))
                  pw.Text('$b C:  ${bandas[b]!.toStringAsFixed(1)} kWh/100km'),
              pw.SizedBox(height: 10),
              pw.Text(
                es
                    ? 'Consumo estimado desde el SoC del coche; coste con el precio de cada dia (PVPC o tarifa). Generado por LMB10.'
                    : 'Estimated consumption from car SoC; cost uses each day price. Generated by LMB10.',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
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

  pw.Widget _pdfDato(String etiqueta, String valor) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(etiqueta, style: const pw.TextStyle(fontSize: 8, color: PdfColors.blue900)),
          pw.Text(valor, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
        ],
      );

  /// Agregacion mensual para ventanas largas: [mes, km, kwh100, eur].
  List<List<String>> _mensual() {
    final km = <String, double>{};
    final eur = <String, double>{};
    final kw = <String, double>{};
    for (final d in _dias) {
      final m = d.d.substring(0, 7);
      km[m] = (km[m] ?? 0) + d.km;
      eur[m] = (eur[m] ?? 0) + d.coste;
      kw[m] = (kw[m] ?? 0) + d.kwh100 * d.km; // ponderado por km
    }
    final out = <List<String>>[];
    for (final m in km.keys.toList()..sort()) {
      final k = km[m]!;
      out.add([m, k.toStringAsFixed(0),
               k > 0 ? (kw[m]! / k).toStringAsFixed(1) : '--',
               (eur[m] ?? 0).toStringAsFixed(2)]);
    }
    return out;
  }

  void _abrirTicket() {
    if (_dias.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TicketScreen(
        desde: DateTime.parse(_dias.first.d),
        hasta: DateTime.parse(_dias.last.d),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    return Scaffold(
      appBar: AppBar(
        title: Text(es ? 'Informe de consumo' : 'Consumption report'),
        actions: [
          IconButton(
            tooltip: es ? 'Ticket termico (imprimir)' : 'Thermal ticket (print)',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: _dias.isEmpty ? null : _abrirTicket,
          ),
          IconButton(
            tooltip: es ? 'Exportar PDF' : 'Export PDF',
            icon: _exportando
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _exportando || _dias.isEmpty ? null : _exportarPdf,
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _todos.isEmpty
              ? Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(es
                      ? 'Aun no hay datos de consumo. Conduce unos dias y vuelve.'
                      : 'No consumption data yet. Drive for a few days and come back.'),
                ))
              : ListView(
                  padding: EdgeInsets.fromLTRB(
                      16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
                  children: [
                    Wrap(spacing: 8, children: [
                      ChoiceChip(
                        label: Text(es ? '7 dias' : '7 days'),
                        selected: _per == _Per.s7,
                        onSelected: (_) => setState(() { _per = _Per.s7; _aplicarPeriodo(); }),
                      ),
                      ChoiceChip(
                        label: Text(es ? '30 dias' : '30 days'),
                        selected: _per == _Per.s30,
                        onSelected: (_) => setState(() { _per = _Per.s30; _aplicarPeriodo(); }),
                      ),
                      ChoiceChip(
                        label: Text(es ? 'Todo' : 'All'),
                        selected: _per == _Per.todo,
                        onSelected: (_) => setState(() { _per = _Per.todo; _aplicarPeriodo(); }),
                      ),
                      ChoiceChip(
                        label: Text(es ? 'Rango…' : 'Range…'),
                        selected: _per == _Per.rango,
                        onSelected: (_) => _elegirRango(),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    if (_dias.isEmpty)
                      Text(es
                          ? 'Sin dias con datos en ese periodo.'
                          : 'No days with data in that period.')
                    else ...[
                      _resumen(es),
                      const SizedBox(height: 12),
                      Text(es ? 'Consumo diario (kWh/100 km)' : 'Daily consumption (kWh/100 km)',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 150,
                        child: CustomPaint(
                          painter: _BarrasConsumo(
                              _dias.length > 62
                                  ? _dias.sublist(_dias.length - 62)
                                  : _dias,
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
                            ? 'Consumo estimado desde el SoC del coche. Coste con el precio de cada dia. El ticket termico y el PDF usan el mismo rango.'
                            : 'Estimated consumption from car SoC. Cost uses each day price. Thermal ticket and PDF use the same range.',
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      ),
                    ],
                  ],
                ),
    );
  }

  Widget _resumen(bool es) {
    final obj = _objetivo;
    final sobreObj = obj > 0 ? (_media100 - obj) / obj * 100.0 : 0.0;
    final colorVar = !_hayPrev
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
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(es ? 'Resumen del periodo' : 'Period summary',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Color(0xFF0D3B66))),
            Text('${_fecha(_dias.first.d)} - ${_fecha(_dias.last.d)}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF0D3B66))),
          ]),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _dato(es ? 'Km' : 'Km', _kmTotal.toStringAsFixed(0)),
            _dato(es ? 'Media' : 'Avg', '${_media100.toStringAsFixed(1)}'),
            _dato('EUR', _costeTotal.toStringAsFixed(2)),
            _dato(es ? 'EUR/100' : 'EUR/100', _eur100.toStringAsFixed(2)),
          ]),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _dato(es ? 'Objetivo' : 'Target', '${obj.toStringAsFixed(1)}',
                color: const Color(0xFF0D3B66)),
            _dato(
                es ? 'Sobre obj.' : 'Vs target',
                '${sobreObj >= 0 ? "+" : ""}${sobreObj.toStringAsFixed(0)} %',
                color: sobreObj <= 3
                    ? const Color(0xFF2A9D8F)
                    : const Color(0xFFE76F51)),
            if (_hayPrev)
              _dato(es ? 'Vs anterior' : 'Vs previous',
                  '${_varPct >= 0 ? "+" : ""}${_varPct.toStringAsFixed(1)} %',
                  color: colorVar),
          ]),
          if (_mejor != null) ...[
            const SizedBox(height: 6),
            Text(
              es
                  ? 'Mejor dia: ${_fecha(_mejor!.d)} (${_mejor!.kwh100.toStringAsFixed(1)})  ·  Peor: ${_fecha(_peor!.d)} (${_peor!.kwh100.toStringAsFixed(1)}) kWh/100km'
                  : 'Best day: ${_fecha(_mejor!.d)} (${_mejor!.kwh100.toStringAsFixed(1)})  ·  Worst: ${_fecha(_peor!.d)} (${_peor!.kwh100.toStringAsFixed(1)})',
              style: const TextStyle(fontSize: 12, color: Color(0xFF0D3B66)),
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
              style: const TextStyle(fontSize: 10, color: Color(0xFF0D3B66))),
          Text(valor,
              style: TextStyle(
                  fontSize: 14,
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
                      child: Text('$b C', style: const TextStyle(fontFamily: 'monospace'))),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (bandas[b]! / 30.0).clamp(0.0, 1.0).toDouble(),
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${bandas[b]!.toStringAsFixed(1)} kWh/100',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                ],
              ),
            ),
      ],
    );
  }
}

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
    final salto = (dias.length / 6).ceil();
    for (var i = 0; i < dias.length; i++) {
      final h = (base - 4) * (dias[i].kwh100 / maxV);
      canvas.drawRect(
        Rect.fromLTWH(i * ancho + 1, base - h, math.max(1.0, ancho - 2), h),
        paint,
      );
      if (i % salto == 0 || i == dias.length - 1) {
        tp.text = TextSpan(
            text: dias[i].d.substring(8),
            style: TextStyle(fontSize: 8, color: Colors.grey.shade600));
        tp.layout();
        tp.paint(canvas, Offset(i * ancho, base + 2));
      }
    }
  }

  @override
  bool shouldRepaint(_BarrasConsumo old) => old.dias != dias;
}
