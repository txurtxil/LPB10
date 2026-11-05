// efficiency_hero.dart — v256: resumen de eficiencia en la pantalla principal.
// v259: CACHE stale-while-revalidate (se pinta al instante con lo ultimo
// calculado y se recalcula en segundo plano con cargas PARALELAS) + tick de
// refresco enganchado al boton de recarga de la barra.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'battery_health.dart' show MuestraBat;
import 'daily_stats.dart';
import 'energy_cost.dart' show preciosPorDia, totalizar;
import 'history_archive.dart';
import 'pvpc.dart';

class EfficiencyHero extends StatefulWidget {
  const EfficiencyHero({super.key});

  /// Tick global: al incrementarlo, el héroe se recalcula (lo dispara el
  /// boton de refresco de la barra principal).
  static final ValueNotifier<int> refreshTick = ValueNotifier<int>(0);

  @override
  State<EfficiencyHero> createState() => _EfficiencyHeroState();
}

class _EfficiencyHeroState extends State<EfficiencyHero> {
  static const String _cacheKey = 'effhero_cache_v1';
  static const double _co2TermicoGkm = 140.0;
  static const double _co2RedGkwh = 150.0;

  bool _cargando = true;
  double? _odo;
  double _ahorro = 0, _co2 = 0, _eurTotal = 0, _termicoEur = 0;
  double _kmMes = 0, _eurMes = 0, _termicoMes = 0;
  int _diasPrecio = 0;
  double _litros = 7.0, _precio = 1.7;
  final List<double> _spark = [];

  @override
  void initState() {
    super.initState();
    EfficiencyHero.refreshTick.addListener(_recalc);
    _iniciar();
  }

  @override
  void dispose() {
    EfficiencyHero.refreshTick.removeListener(_recalc);
    super.dispose();
  }

  Future<void> _iniciar() async {
    // 1) Cache: pintar al INSTANTE con lo ultimo calculado.
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw != null) {
        final m = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        _ahorro = (m['ahorro'] ?? 0).toDouble();
        _co2 = (m['co2'] ?? 0).toDouble();
        _eurTotal = (m['eurTotal'] ?? 0).toDouble();
        _termicoEur = (m['termicoEur'] ?? 0).toDouble();
        _kmMes = (m['kmMes'] ?? 0).toDouble();
        _eurMes = (m['eurMes'] ?? 0).toDouble();
        _termicoMes = (m['termicoMes'] ?? 0).toDouble();
        _litros = (m['litros'] ?? 7).toDouble();
        _precio = (m['precio'] ?? 1.7).toDouble();
        final o = m['odo'];
        _odo = o == null ? null : (o).toDouble();
        _spark
          ..clear()
          ..addAll((m['spark'] as List? ?? [])
              .map((e) => (e).toDouble()));
      }
    } catch (_) {}
    if (mounted) setState(() => _cargando = false);
    // 2) Recalcular en segundo plano (cache stale-while-revalidate).
    _recalc();
  }

  void _recalc() {
    _calcular();
  }

  Future<void> _calcular() async {
    try {
      // Cargas PARALELAS (antes secuenciales -> lento).
      final res = await Future.wait<dynamic>([
        DailyStats.sync(),
        preciosPorDia(),
        Pvpc.termico(),
        HistoryArchive.cargarMuestrasBat()
            .catchError((_) => <MuestraBat>[]),
      ]);
      final days = res[0] as List<DayAgg>;
      final precios = res[1] as Map<String, double>;
      final term = res[2] as ({double litros, double precio});
      final muestras = res[3] as List<MuestraBat>;
      _litros = term.litros > 0 ? term.litros.toDouble() : 7.0;
      _precio = term.precio > 0 ? term.precio.toDouble() : 1.7;

      double km = 0, eur = 0, kwh = 0, kmMes = 0, eurMes = 0, kmEur = 0;
      var diasPrecio = 0;
      final mesActual = DateTime.now().toIso8601String().substring(0, 7);
      for (final a in days) {
        final t = totalizar([a], precios);
        km += t.km;
        kwh += t.kwh;
        if (t.hayEur) {
          eur += t.eur;
          kmEur += t.km;
          diasPrecio++;
        }
        if (a.d.startsWith(mesActual)) {
          kmMes += t.km;
          if (t.hayEur) eurMes += t.eur;
        }
      }

      final conKm = days.where((a) => a.kmAll >= 0.5).toList();
      final ult =
          conKm.length > 14 ? conKm.sublist(conKm.length - 14) : conKm;
      final spark = <double>[];
      for (final a in ult) {
        final td = totalizar([a], precios);
        if (td.km >= 0.5) spark.add(td.kwh * 100 / td.km);
      }

      double odo = 0;
      for (final x in muestras) {
        if (x.km > odo) odo = x.km.toDouble();
      }

      // v262 (issue #4): el ahorro debe comparar AMBOS lados sobre el
      // MISMO alcance. Antes el térmico usaba el odómetro completo (vida
      // del coche) mientras el eléctrico solo sumaba los días con precio
      // conocido: se mezclaba un periodo parcial con la vida entera y el
      // ahorro salía inflado. Ahora el térmico se calcula sobre los km
      // de los días con precio (kmEur), el mismo alcance que el coste
      // eléctrico. El odómetro queda solo como dato informativo (_odo).
      final ahorro = kmEur * _litros / 100 * _precio - eur;
      final kwhKm = km > 10 ? kwh / km : 0.18;
      final co2 = (_co2TermicoGkm - _co2RedGkwh * kwhKm) * odo / 1000;

      if (!mounted) return;
      setState(() {
        _odo = odo > 0 ? odo : null;
        _eurTotal = eur;
        _termicoEur = kmEur * _litros / 100 * _precio;
        _ahorro = ahorro;
        _co2 = co2;
        _kmMes = kmMes;
        _eurMes = eurMes;
        _termicoMes = kmMes * _litros / 100 * _precio;
        _diasPrecio = diasPrecio;
        _spark
          ..clear()
          ..addAll(spark);
      });
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheKey, jsonEncode({
          'ahorro': _ahorro,
          'co2': _co2,
          'eurTotal': _eurTotal,
          'termicoEur': _termicoEur,
          'kmMes': _kmMes,
          'eurMes': _eurMes,
          'termicoMes': _termicoMes,
          'litros': _litros,
          'precio': _precio,
          'odo': _odo,
          'spark': _spark,
        }));
      } catch (_) {}
    } catch (_) {}
  }

  String _eur(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');

  double _promedio() =>
      _spark.isEmpty ? 0 : _spark.reduce((a, b) => a + b) / _spark.length;

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    if (_cargando) return const SizedBox(height: 40);
    if (_odo == null && _spark.isEmpty) return const SizedBox.shrink();
    final maxMes = _termicoMes > _eurMes ? _termicoMes : _eurMes;
    final pcMes = _termicoMes > 0 ? _eurMes / _termicoMes : 0.0;
    return Column(children: [
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(es ? 'AHORRO ACUMULADO VS TÉRMICO' : 'CUMULATIVE SAVINGS VS THERMAL',
                style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_eur(_ahorro), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF4CC38A))),
                Text(es ? 'ahorrados' : 'saved', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              ])),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${_co2.toStringAsFixed(0)} kg', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(es ? 'CO2 evitado' : 'CO2 avoided', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              ])),
              if (_odo != null)
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${_odo!.toStringAsFixed(0)} km', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(es ? 'odómetro' : 'odometer', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                ])),
            ]),
            const SizedBox(height: 8),
            Text(
              es
                  ? 'electricidad ${_eurTotal.toStringAsFixed(2)}€ · un térmico (${_litros.toStringAsFixed(1)} L/100km a ${_precio.toStringAsFixed(2)}€/L) habría costado ${_eur(_termicoEur)}€ · basado en $_diasPrecio días con precio'
                  : 'electricity ${_eurTotal.toStringAsFixed(2)}€ · a thermal (${_litros.toStringAsFixed(1)} L/100km at ${_precio.toStringAsFixed(2)}€/L) would have cost ${_eur(_termicoEur)}€ · based on $_diasPrecio priced days',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(es ? 'ESTE MES: ${_kmMes.toStringAsFixed(0)} km' : 'THIS MONTH: ${_kmMes.toStringAsFixed(0)} km',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold)),
              Text(pcMes > 0 ? (es ? 'elec. = ${(pcMes * 100).toStringAsFixed(0)}% del térmico' : 'elec. = ${(pcMes * 100).toStringAsFixed(0)}% of thermal') : '',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            ]),
            const SizedBox(height: 8),
            _barra(es ? 'eléctrico' : 'electric', _eurMes, maxMes, const Color(0xFF4CC38A)),
            const SizedBox(height: 4),
            _barra(es ? 'térmico' : 'thermal', _termicoMes, maxMes, const Color(0xFFE5A04C)),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      if (_spark.length >= 2)
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(es ? 'CONSUMO ÚLTIMOS ${_spark.length} DÍAS' : 'CONSUMPTION LAST ${_spark.length} DAYS',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold)),
                Text('${_promedio().toStringAsFixed(1)} kWh/100km',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF4CC38A), fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 6),
              SizedBox(height: 56, width: double.infinity, child: CustomPaint(painter: _SparkPainter(_spark))),
            ]),
          ),
        ),
      const SizedBox(height: 8),
    ]);
  }

  Widget _barra(String label, double valor, double max, Color color) {
    final w = max > 0 ? (valor / max).clamp(0.0, 1.0) : 0.0;
    return Row(children: [
      SizedBox(width: 62, child: Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500]))),
      Expanded(
        child: Stack(children: [
          Container(height: 10, decoration: BoxDecoration(color: const Color(0xFF24242E), borderRadius: BorderRadius.circular(5))),
          FractionallySizedBox(
            widthFactor: w,
            child: Container(height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5))),
          ),
        ]),
      ),
      const SizedBox(width: 6),
      SizedBox(width: 52, child: Text('${_eur(valor)}€', style: const TextStyle(fontSize: 10), textAlign: TextAlign.right)),
    ]);
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> vals;
  _SparkPainter(this.vals);
  @override
  void paint(Canvas canvas, Size size) {
    if (vals.length < 2) return;
    final min = vals.reduce((a, b) => a < b ? a : b) * 0.95;
    final max = vals.reduce((a, b) => a > b ? a : b) * 1.05;
    final dx = size.width / (vals.length - 1);
    double y(double v) => size.height - (v - min) / (max - min) * size.height;
    final path = Path();
    for (var i = 0; i < vals.length; i++) {
      final p = Offset(i * dx, y(vals[i]));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(area, Paint()
      ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [const Color(0xFF8B7CF6).withOpacity(0.35), const Color(0xFF8B7CF6).withOpacity(0.0)]).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));
    canvas.drawPath(path, Paint()..color = const Color(0xFF8B7CF6)..strokeWidth = 2.0
      ..style = PaintingStyle.stroke);
    canvas.drawCircle(Offset((vals.length - 1) * dx, y(vals.last)), 3.2, Paint()..color = const Color(0xFF4CC38A));
  }
  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.vals != vals;
}
