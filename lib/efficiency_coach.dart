// efficiency_coach.dart — Coach de eficiencia: medias reales vs objetivo y
// consejos accionables. Honesto: no desglosa Conduccion/AC/Otros (ese dato
// no esta en el API, solo en la pantalla del coche).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'leapmotor_engine.dart';
import 'widget_chart.dart' show gBatteryKwh, gMaxRangeKm;

// Estas tres se quedaron fuera cuando se creo el perfil de vehiculo: eran
// copias privadas con otro nombre, asi que el renombrado no las cazo y esta
// pantalla seguia calculando con la bateria del B10 aunque el usuario hubiese
// elegido otro modelo. GETTERS, no final: un final de nivel superior se
// calcula una sola vez y se quedaria con el valor por defecto si el perfil se
// carga despues.
double get _battKwh => gBatteryKwh;
double get _maxRange => gMaxRangeKm;
double get _target => gBatteryKwh / gMaxRangeKm * 100.0;
const _storage = FlutterSecureStorage();

class EfficiencyCoachScreen extends StatefulWidget {
  const EfficiencyCoachScreen({super.key, this.status});
  final VehicleStatus? status;

  @override
  State<EfficiencyCoachScreen> createState() => _EfficiencyCoachScreenState();
}

class _EfficiencyCoachScreenState extends State<EfficiencyCoachScreen> {
  bool _loading = true;
  double? _media;
  double _km = 0;
  int _charges = 0;
  int _shortCharges = 0;

  @override
  void initState() {
    super.initState();
    _compute();
  }

  Future<List<({int ts, int km, double soc})>> _readPermanentTrips() async {
    final out = <({int ts, int km, double soc})>[];
    try {
      final base = await getApplicationDocumentsDirectory();
      final f = File('${base.path}/lmb10_history/trips.jsonl');
      if (!await f.exists()) return out;
      for (final line in await f.readAsLines()) {
        final t = line.trim();
        if (t.isEmpty) continue;
        try {
          final m = Map<String, dynamic>.from(json.decode(t) as Map);
          if (m['ts'] is int && m['km'] is int && m['soc'] is num) {
            out.add((ts: m['ts'] as int, km: m['km'] as int, soc: (m['soc'] as num).toDouble()));
          }
        } catch (_) {}
      }
      out.sort((a, b) => a.ts.compareTo(b.ts));
    } catch (_) {}
    return out;
  }

  Future<void> _compute() async {
    try {
      final chargeRaw = await _storage.read(key: 'lm_charge_history_v1');
      final since = DateTime.now().subtract(const Duration(days: 30));

      double km = 0, drop = 0;
      var perm = await _readPermanentTrips();
      if (perm.isEmpty) {
        final tripRaw = await _storage.read(key: 'lm_trip_points_v1');
        if (tripRaw != null) {
          for (final e in (json.decode(tripRaw) as List)) {
            final m = Map<String, dynamic>.from(e as Map);
            perm.add((ts: m['ts'] as int, km: m['km'] as int, soc: (m['soc'] as num).toDouble()));
          }
        }
      }
      final pts = perm
          .where((p) => DateTime.fromMillisecondsSinceEpoch(p.ts).isAfter(since))
          .toList();
      for (var i = 1; i < pts.length; i++) {
        final kmD = (pts[i].km - pts[i - 1].km).toDouble();
        final socD = pts[i - 1].soc - pts[i].soc;
        if (kmD <= 0 || socD <= 0) continue;
        // Cordura: descartar solo tramos fisicamente imposibles.
        final pct = socD / kmD * 100;
        if (pct < 8.0 || pct > 70.0) continue;
        km += kmD;
        drop += socD;
      }
      if (chargeRaw != null) {
        for (final e in (json.decode(chargeRaw) as List)) {
          final m = Map<String, dynamic>.from(e as Map);
          final endSoc = m['endSoc'];
          final startSoc = m['startSoc'];
          if (endSoc is num && startSoc is num && (endSoc - startSoc) >= 1.0) {
            _charges++;
            if ((endSoc - startSoc) < 15) _shortCharges++;
          }
        }
      }
      _km = km;
      // Red de seguridad: media implausible => no se muestra dato.
      final avgPct = (km >= 5 && drop > 0) ? drop / km * 100 : null;
      _media = (avgPct != null && avgPct >= 12.0 && avgPct <= 70.0)
          ? drop * _battKwh / km
          : null;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    return Scaffold(
      appBar: AppBar(title: Text(es ? 'Coach de eficiencia' : 'Efficiency coach')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: _cards(es),
            ),
    );
  }

  List<Widget> _cards(bool es) {
    final cards = <Widget>[];
    final m = _media;

    if (m == null) {
      cards.add(_card(
        Icons.info_outline,
        es ? 'Sin datos suficientes' : 'Not enough data',
        es
            ? 'Conduce unos dias para calcular tu consumo medio real.'
            : 'Drive a few days to compute your real average consumption.',
      ));
      return cards;
    }

    final ok = m <= _target;
    final estKm = (_battKwh / m * 100).round();
    final targetKm = _maxRange.round();
    final gain = targetKm - estKm;

    cards.add(Card(
      color: ok ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              es ? 'Tu media (30 dias)' : 'Your average (30 days)',
              style: TextStyle(color: Colors.blueGrey.shade900, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text('${_d1(m)} kWh/100 km',
                style: TextStyle(
                    color: Colors.blueGrey.shade900,
                    fontSize: 26,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              es
                  ? 'Objetivo: ${_d1(_target)} ($targetKm km).  Tu autonomia real: ~$estKm km.'
                  : 'Target: ${_d1(_target)} ($targetKm km).  Your real range: ~$estKm km.',
              style: TextStyle(color: Colors.blueGrey.shade900, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              ok
                  ? (es ? 'Vas por debajo del objetivo. Excelente.' : 'Below target. Excellent.')
                  : (es
                      ? 'Bajando al objetivo ganarias ~$gain km por carga.'
                      : 'Reaching target would add ~$gain km per charge.'),
              style: TextStyle(
                  color: ok ? Colors.green.shade900 : Colors.orange.shade900,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
          ],
        ),
      ),
    ));

    final tips = <String>[];
    if (!ok) {
      tips.add(es
          ? 'Reduce velocidad en autovia: pasar de 120 a 110 km/h es el mayor ahorro de autonomia que existe.'
          : 'Slow down on the motorway: 120->110 km/h is the single biggest range saver.');
    }
    final it = widget.status?.raw['interiorTemp'];
    final interior = it is num ? it.toDouble() : (it is String ? double.tryParse(it) : null);
    if (interior != null) {
      tips.add(es
          ? 'Habitaculo a ${interior.toStringAsFixed(0)} C. En verano, cada grado que subas el A/C baja el consumo de clima; el punto dulce esta en 21-23 C.'
          : 'Cabin at ${interior.toStringAsFixed(0)} C. In summer, each degree up on the A/C cuts climate use; sweet spot is 21-23 C.');
    } else {
      tips.add(es
          ? 'En verano sube el A/C a 21-23 C: menos salto termico con el exterior = menos consumo de clima.'
          : 'In summer set A/C to 21-23 C: less thermal gap = less climate use.');
    }
    tips.add(es
        ? 'Preacondiciona con el coche enchufado antes de salir: el pico de clima lo paga la red, no la bateria.'
        : 'Precondition while plugged in before leaving: the climate peak comes from the grid, not the battery.');
    if (_shortCharges >= 3) {
      tips.add(es
          ? 'Detectadas varias cargas cortas: cargar de una sola vez suele ser mas eficiente que muchos picotazos.'
          : 'Several short charges detected: one full session is usually more efficient than many top-ups.');
    }
    tips.add(es
        ? 'Revisa la presion de neumaticos: baja presion aumenta el consumo notablemente.'
        : 'Check tire pressure: low pressure noticeably increases consumption.');

    cards.add(const SizedBox(height: 12));
    cards.add(Text(es ? 'Consejos para mejorar' : 'Tips to improve',
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade300)));
    cards.add(const SizedBox(height: 4));
    for (final t in tips) {
      cards.add(Card(
        child: ListTile(
          dense: true,
          leading: const Icon(Icons.eco, color: Colors.green),
          title: Text(t, style: const TextStyle(fontSize: 13)),
        ),
      ));
    }
    return cards;
  }

  Widget _card(IconData icon, String title, String body) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(body, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  static String _d1(num v) => v.toStringAsFixed(1).replaceAll('.', ',');
}
