#!/bin/bash
# ============================================================================
# LMB10 - pack_efficiency.sh  —  Clima eficiente (manual/auto) + Coach
#
#  1) lib/weather.dart: temperatura EXTERIOR via GPS + Open-Meteo (sin clave),
#     con cache de 15 min y fallback silencioso. El coche NO expone la temp
#     exterior (solo interiorTemp), por eso se usa el tiempo por ubicacion.
#  2) lib/efficient_climate.dart: elige la temperatura de preacondicionamiento
#     por franja de temp exterior, buscando el minimo salto termico confortable
#     (= menos A/C = mas autonomia). Modo Manual (eliges estacion) o Auto (API).
#       ext >28  -> frio 23 + recirculacion             (verano)
#       18..28   -> nada (zona de maxima eficiencia)     (templado)
#       5..18    -> calor 20 + volante                   (invierno)
#       <5       -> calor 20 + volante + precalentar bat (frio extremo)
#     Todo solo si el coche esta ENCHUFADO (energia de red, no de bateria).
#  3) lib/efficiency_coach.dart: pantalla "Coach" con tu media real kWh/100 vs
#     objetivo 15,6, autonomia que ganarias, y consejos accionables. Usa
#     interiorTemp para el consejo de clima. Honesto: no desglosa
#     Conduccion/AC/Otros (ese dato no esta en el API, solo en el coche).
#
#  Integra: tarjeta "Clima eficiente" arriba en Rutinas + icono Coach en AppBar.
# Ejecutar desde la raiz: bash pack_efficiency.sh
# ============================================================================
set -e
[ -f lib/main.dart ] || { echo "ERROR: ejecuta desde la raiz del proyecto."; exit 1; }
mkdir -p backups_widget
cp lib/main.dart backups_widget/main.dart.bak_eff
cp lib/routines/routines_screen.dart backups_widget/routines_screen.dart.bak_eff

# ---------------------------------------------------------------------------
# 1) lib/weather.dart
# ---------------------------------------------------------------------------
cat > lib/weather.dart << 'EOF'
// weather.dart — Temperatura exterior actual via GPS + Open-Meteo (sin clave).
// El coche no expone la temp exterior por API; se estima por la ubicacion.
// Cache de 15 min y fallback silencioso (null) si no hay permiso/red.

import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class Weather {
  static double? _cachedTemp;
  static DateTime? _cachedAt;

  /// Temperatura exterior en grados C, o null si no se pudo obtener.
  static Future<double?> outdoorTemp() async {
    if (_cachedTemp != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < const Duration(minutes: 15)) {
      return _cachedTemp;
    }
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
      final url = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=${pos.latitude}&longitude=${pos.longitude}&current=temperature_2m');
      final r = await http.get(url).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      final j = json.decode(r.body) as Map<String, dynamic>;
      final cur = j['current'];
      final t = (cur is Map ? cur['temperature_2m'] : null) as num?;
      if (t != null) {
        _cachedTemp = t.toDouble();
        _cachedAt = DateTime.now();
      }
      return _cachedTemp;
    } catch (_) {
      return null;
    }
  }
}
EOF
echo "OK  lib/weather.dart"

# ---------------------------------------------------------------------------
# 2) lib/efficient_climate.dart
# ---------------------------------------------------------------------------
cat > lib/efficient_climate.dart << 'EOF'
// efficient_climate.dart — Preacondicionamiento eficiente por temp exterior.
// Menos salto termico = menos A/C = mas autonomia. Solo con coche enchufado.

import 'leapmotor_engine.dart';
import 'weather.dart';

enum ClimateMode { auto, summer, mild, winter, extremeCold }

class EfficientClimateResult {
  final bool ok;
  final String summary;
  EfficientClimateResult(this.ok, this.summary);
}

/// Mapea una temperatura exterior a un modo por franjas.
ClimateMode modeForTemp(double t) {
  if (t > 28) return ClimateMode.summer;
  if (t >= 18) return ClimateMode.mild;
  if (t >= 5) return ClimateMode.winter;
  return ClimateMode.extremeCold;
}

String climateModeLabel(ClimateMode m, {required bool es}) {
  switch (m) {
    case ClimateMode.auto:
      return es ? 'Automatico (tiempo)' : 'Automatic (weather)';
    case ClimateMode.summer:
      return es ? 'Verano (frio 23)' : 'Summer (cool 23)';
    case ClimateMode.mild:
      return es ? 'Templado (sin clima)' : 'Mild (no climate)';
    case ClimateMode.winter:
      return es ? 'Invierno (calor 20)' : 'Winter (heat 20)';
    case ClimateMode.extremeCold:
      return es ? 'Frio extremo (calor+bat)' : 'Extreme cold (heat+batt)';
  }
}

/// Aplica el clima eficiente. Si [mode] es auto, consulta el tiempo por GPS.
/// Requiere coche enchufado; si no lo esta, no hace nada (y lo explica).
Future<EfficientClimateResult> applyEfficientClimate({
  required LeapmotorApiClient client,
  required String vin,
  required String pin,
  required ClimateMode mode,
  VehicleStatus? status,
  bool requirePluggedIn = true,
}) async {
  if (requirePluggedIn && status != null && status.isPluggedIn != true) {
    return EfficientClimateResult(false,
        'Coche no enchufado: no se aplica (para no gastar bateria). Enchufalo y reintenta.');
  }

  ClimateMode effective = mode;
  double? extTemp;
  if (mode == ClimateMode.auto) {
    extTemp = await Weather.outdoorTemp();
    if (extTemp == null) {
      return EfficientClimateResult(false,
          'No se pudo leer la temperatura exterior (permiso/red). Elige un modo manual.');
    }
    effective = modeForTemp(extTemp);
  }

  final tempStr = extTemp != null
      ? ' (ext ${extTemp.toStringAsFixed(0)} C)'
      : '';

  try {
    switch (effective) {
      case ClimateMode.auto:
        break; // ya resuelto
      case ClimateMode.summer:
        await client.prepareCarNow(vin, pin,
            heat: false, temperature: '23', steeringWheelHeat: false);
        return EfficientClimateResult(
            true, 'Verano$tempStr: frio 23 activado. Menos salto termico = menos A/C.');
      case ClimateMode.mild:
        return EfficientClimateResult(true,
            'Templado$tempStr: sin climatizar. Es la zona de maxima eficiencia.');
      case ClimateMode.winter:
        await client.prepareCarNow(vin, pin,
            heat: true, temperature: '20', steeringWheelHeat: true);
        return EfficientClimateResult(true,
            'Invierno$tempStr: calor 20 + volante. Calentar a la persona gasta menos que el aire.');
      case ClimateMode.extremeCold:
        await client.prepareCarNow(vin, pin,
            heat: true, temperature: '20', steeringWheelHeat: true);
        await client.batteryPreheatOn(vin, pin);
        return EfficientClimateResult(true,
            'Frio extremo$tempStr: calor 20 + volante + precalentar bateria (mejora rendimiento y regeneracion).');
    }
  } catch (e) {
    return EfficientClimateResult(false, 'Error al aplicar: $e');
  }
  return EfficientClimateResult(false, 'Modo no valido');
}
EOF
echo "OK  lib/efficient_climate.dart"

# ---------------------------------------------------------------------------
# 3) lib/efficiency_coach.dart
# ---------------------------------------------------------------------------
cat > lib/efficiency_coach.dart << 'EOF'
// efficiency_coach.dart — Coach de eficiencia: medias reales vs objetivo y
// consejos accionables. Honesto: no desglosa Conduccion/AC/Otros (ese dato
// no esta en el API, solo en la pantalla del coche).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'leapmotor_engine.dart';

const double _battKwh = 67.1;
const double _maxRange = 430.0;
final double _target = _battKwh / _maxRange * 100.0; // 15,6
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

  Future<void> _compute() async {
    try {
      final tripRaw = await _storage.read(key: 'lm_trip_points_v1');
      final chargeRaw = await _storage.read(key: 'lm_charge_history_v1');
      final since = DateTime.now().subtract(const Duration(days: 30));

      double km = 0, drop = 0;
      if (tripRaw != null) {
        final pts = (json.decode(tripRaw) as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((m) =>
                DateTime.fromMillisecondsSinceEpoch(m['ts'] as int).isAfter(since))
            .toList();
        for (var i = 1; i < pts.length; i++) {
          final kmD = ((pts[i]['km'] as int) - (pts[i - 1]['km'] as int)).toDouble();
          final socD = (pts[i - 1]['soc'] as num).toDouble() -
              (pts[i]['soc'] as num).toDouble();
          if (kmD > 0 && socD > 0) {
            km += kmD;
            drop += socD;
          }
        }
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
      _media = (km > 0 && drop > 0) ? drop * _battKwh / km : null;
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
                  ? 'Objetivo: ${_d1(_target)} (430 km).  Tu autonomia real: ~$estKm km.'
                  : 'Target: ${_d1(_target)} (430 km).  Your real range: ~$estKm km.',
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
EOF
echo "OK  lib/efficiency_coach.dart"

# ---------------------------------------------------------------------------
# 4) main.dart: imports + icono Coach en el AppBar (junto al ticket)
# ---------------------------------------------------------------------------
python3 << 'PYEOF'
import sys
p = 'lib/main.dart'
s = open(p, encoding='utf-8').read()

def one(a,b,label):
    global s
    if s.count(a)!=1:
        print(f"ERROR '{label}': ancla x{s.count(a)}"); sys.exit(1)
    s=s.replace(a,b); print(f"OK  {label}")

one("import 'ticket_screen.dart';",
    "import 'ticket_screen.dart';\nimport 'efficiency_coach.dart';",
    'import coach')

one("""          IconButton(
            icon: const Icon(Icons.receipt_long),""",
    """          IconButton(
            icon: const Icon(Icons.eco_outlined),
            tooltip: Localizations.localeOf(context).languageCode == 'es' ? 'Coach de eficiencia' : 'Efficiency coach',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => EfficiencyCoachScreen(status: _status),
            )),
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long),""",
    'icono Coach en AppBar')

open(p,'w',encoding='utf-8').write(s)
print("OK  main.dart parcheado")
PYEOF

# ---------------------------------------------------------------------------
# 5) routines_screen.dart: tarjeta "Clima eficiente"
# ---------------------------------------------------------------------------
python3 << 'PYEOF'
import sys
p = 'lib/routines/routines_screen.dart'
s = open(p, encoding='utf-8').read()

if "import '../efficient_climate.dart';" not in s:
    a = "import 'routine_engine.dart';"
    if s.count(a)!=1: print(f"ERROR import: x{s.count(a)}"); sys.exit(1)
    s = s.replace(a, a + "\nimport '../efficient_climate.dart';")

a = "  bool _busy = false;"
if s.count(a)!=1: print(f"ERROR estado: x{s.count(a)}"); sys.exit(1)
s = s.replace(a, "  bool _busy = false;\n  ClimateMode _climateMode = ClimateMode.auto;")

a = "  Future<void> _toggleFavorite(Routine r) async {"
m = """  Future<void> _applyClimate() async {
    setState(() => _busy = true);
    final res = await applyEfficientClimate(
      client: widget.client,
      vin: widget.vin,
      pin: widget.pin,
      mode: _climateMode,
      status: widget.status,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res.summary),
        backgroundColor: res.ok ? null : Colors.orange.shade800,
        duration: const Duration(seconds: 6)));
  }

  Future<void> _toggleFavorite(Routine r) async {"""
if s.count(a)!=1: print(f"ERROR metodo: x{s.count(a)}"); sys.exit(1)
s = s.replace(a, m)

a = "                const SizedBox(height: 8),\n                ..._routines.map((r) => _routineCard(r, es)),"
card = """                const SizedBox(height: 8),
                _climateCard(es),
                const SizedBox(height: 8),
                ..._routines.map((r) => _routineCard(r, es)),"""
if s.count(a)!=1: print(f"ERROR tarjeta: x{s.count(a)}"); sys.exit(1)
s = s.replace(a, card)

a = "  Widget _routineCard(Routine r, bool es) {"
w = """  Widget _climateCard(bool es) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.thermostat, color: Colors.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(es ? 'Clima eficiente' : 'Efficient climate',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              es
                  ? 'Preacondiciona con el minimo salto termico (menos A/C = mas autonomia). Solo si el coche esta enchufado.'
                  : 'Precondition with the smallest thermal gap (less A/C = more range). Only when plugged in.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            DropdownButton<ClimateMode>(
              value: _climateMode,
              isExpanded: true,
              items: ClimateMode.values
                  .map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(climateModeLabel(m, es: es)),
                      ))
                  .toList(),
              onChanged: (m) {
                if (m != null) setState(() => _climateMode = m);
              },
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _applyClimate,
                icon: const Icon(Icons.ac_unit),
                label: Text(es ? 'Aplicar clima eficiente' : 'Apply efficient climate'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _routineCard(Routine r, bool es) {"""
if s.count(a)!=1: print(f"ERROR widget: x{s.count(a)}"); sys.exit(1)
s = s.replace(a, w)

open(p,'w',encoding='utf-8').write(s)
print("OK  routines_screen.dart: tarjeta Clima eficiente")
PYEOF

cat << 'DONE'
============================================================
EFICIENCIA aplicada. Compila:
  flutter build apk --release
============================================================
DONE
