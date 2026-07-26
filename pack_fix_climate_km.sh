#!/bin/bash
# ============================================================================
# LMB10 - Repara clima v2 (bug \$ de interpolacion) + km del ciclo en widget
# ============================================================================
set -e
[ -f lib/main.dart ] || { echo "ERROR: raiz del proyecto"; exit 1; }
mkdir -p backups_widget
cp lib/efficient_climate.dart backups_widget/efficient_climate.dart.bak_fix
cp lib/routines/routine_engine.dart backups_widget/routine_engine.dart.bak_fix
cp lib/routines/routines_screen.dart backups_widget/routines_screen.dart.bak_fix
cp lib/widget_chart.dart backups_widget/widget_chart.dart.bak_fix
cp lib/main.dart backups_widget/main.dart.bak_fix

# --- 0) LIMPIAR \$ -> $ en efficient_climate.dart (bug de interpolacion) ---
sed -i 's/\\\$/$/g' lib/efficient_climate.dart
echo "OK  limpiado \$ en efficient_climate.dart"

# --- 1) Reaplicar bloque 2: permanent + helpers ---
python3 << 'PYEOF'
import sys
p = 'lib/efficient_climate.dart'
s = open(p, encoding='utf-8').read()

one = ("""  VehicleStatus? status,
  bool requirePluggedIn = true,
}) async {""",
"""  VehicleStatus? status,
  bool requirePluggedIn = true,
  bool permanent = false,
}) async {""")
if s.count(one[0])!=1: print(f"ERROR firma: x{s.count(one[0])}"); sys.exit(1)
s = s.replace(one[0], one[1])

anchor2 = "  ClimateMode effective = mode;"
helpers = """  Future<void> applyHeat(String temp, bool wheel) async {
    if (permanent) {
      await client.climateManual(vin, pin, heat: true, temperature: temp);
      if (wheel) await client.steeringWheelHeatOn(vin, pin);
    } else {
      await client.prepareCarNow(vin, pin,
          heat: true, temperature: temp, steeringWheelHeat: wheel);
    }
  }
  Future<void> applyCool(String temp) async {
    if (permanent) {
      await client.climateManual(vin, pin, heat: false, temperature: temp);
    } else {
      await client.prepareCarNow(vin, pin,
          heat: false, temperature: temp, steeringWheelHeat: false);
    }
  }

  ClimateMode effective = mode;"""
if s.count(anchor2)!=1: print(f"ERROR helpers: x{s.count(anchor2)}"); sys.exit(1)
s = s.replace(anchor2, helpers)

subs = [
 ("""        await client.prepareCarNow(vin, pin,
            heat: false, temperature: '23', steeringWheelHeat: false);
        return EfficientClimateResult(
            true, 'Verano$tempStr: frio 23 activado. Menos salto termico = menos A/C.$warn');""",
  """        await applyCool('23');
        return EfficientClimateResult(true,
            'Verano$tempStr frio 23 ${permanent ? "(permanente)" : "(preacond)"}.$warn');"""),

 ("""        await client.prepareCarNow(vin, pin,
            heat: true, temperature: '20', steeringWheelHeat: true);
        return EfficientClimateResult(true,
            'Invierno$tempStr: calor 20 + volante. Calentar a la persona gasta menos que el aire.$warn');""",
  """        await applyHeat('20', true);
        return EfficientClimateResult(true,
            'Invierno$tempStr calor 20 + volante ${permanent ? "(permanente)" : "(preacond)"}.$warn');"""),

 ("""        await client.prepareCarNow(vin, pin,
            heat: true, temperature: '20', steeringWheelHeat: true);
        await client.batteryPreheatOn(vin, pin);
        return EfficientClimateResult(true,
            'Frio extremo$tempStr: calor 20 + volante + precalentar bateria.$warn');""",
  """        await applyHeat('20', true);
        await client.batteryPreheatOn(vin, pin);
        return EfficientClimateResult(true,
            'Frio extremo$tempStr calor 20 + volante + bateria ${permanent ? "(permanente)" : "(preacond)"}.$warn');"""),
]
for a,b in subs:
    if s.count(a)!=1: print(f"ERROR sub: x{s.count(a)}: {a[:45]}"); sys.exit(1)
    s = s.replace(a,b)
open(p,'w',encoding='utf-8').write(s)
print("OK  efficient_climate.dart: permanent + helpers")
PYEOF

# --- 2) Reaplicar bloque 3: routine_engine ---
python3 << 'PYEOF'
import sys
p = 'lib/routines/routine_engine.dart'
s = open(p, encoding='utf-8').read()
def one(a,b,label):
    global s
    if s.count(a)!=1: print(f"ERROR '{label}': x{s.count(a)}"); sys.exit(1)
    s=s.replace(a,b); print(f"OK  {label}")

one("import '../leapmotor_engine.dart';",
    "import '../leapmotor_engine.dart';\nimport '../efficient_climate.dart';",
    'import efficient_climate')
one("  windowsClose, // windowsClose\n}",
    "  windowsClose, // windowsClose\n  efficientClimate, // clima eficiente (intParam=modo, boolParam=permanente)\n}",
    'enum efficientClimate')
one("  Future<RoutineRunResult> run(Routine r, {VehicleStatus? status}) async {",
    "  VehicleStatus? _runStatus;\n  Future<RoutineRunResult> run(Routine r, {VehicleStatus? status}) async {\n    _runStatus = status;",
    'run guarda status')
one("""      case RoutineAction.windowsClose:
        await client.windowsClose(vin, pin);
        break;""",
    """      case RoutineAction.windowsClose:
        await client.windowsClose(vin, pin);
        break;
      case RoutineAction.efficientClimate:
        final mode = ClimateMode.values[
            step.intParam.clamp(0, ClimateMode.values.length - 1)];
        await applyEfficientClimate(
          client: client,
          vin: vin,
          pin: pin,
          mode: mode,
          status: _runStatus,
          permanent: step.boolParam,
          requirePluggedIn: false,
        );
        break;""",
    'execute efficientClimate')
one("""    case RoutineAction.windowsClose:
      return es ? 'Subir ventanillas' : 'Close windows';""",
    """    case RoutineAction.windowsClose:
      return es ? 'Subir ventanillas' : 'Close windows';
    case RoutineAction.efficientClimate:
      final mode = ClimateMode.values[s.intParam.clamp(0, ClimateMode.values.length - 1)];
      final tail = s.boolParam ? (es ? ' permanente' : ' permanent') : (es ? ' preacond.' : ' precond.');
      return (es ? 'Clima ' : 'Climate ') + climateModeLabel(mode, es: es) + tail;""",
    'label efficientClimate')
one("""  static List<Routine> _defaults() => [
        Routine(
          id: 'eco_morning',""",
    """  static List<Routine> _defaults() => [
        Routine(
          id: 'climate_auto',
          name: 'Clima Auto (tiempo)',
          enabled: false,
          steps: [
            RoutineStep(
                action: RoutineAction.efficientClimate,
                intParam: ClimateMode.auto.index,
                boolParam: false),
          ],
        ),
        Routine(
          id: 'climate_summer',
          name: 'Clima Verano 23 permanente',
          enabled: false,
          steps: [
            RoutineStep(
                action: RoutineAction.efficientClimate,
                intParam: ClimateMode.summer.index,
                boolParam: true),
          ],
        ),
        Routine(
          id: 'climate_winter',
          name: 'Clima Invierno 20 permanente',
          enabled: false,
          steps: [
            RoutineStep(
                action: RoutineAction.efficientClimate,
                intParam: ClimateMode.winter.index,
                boolParam: true),
          ],
        ),
        Routine(
          id: 'eco_morning',""",
    'rutinas preset de clima')
open(p,'w',encoding='utf-8').write(s)
print("OK  routine_engine.dart listo")
PYEOF

# --- 3) Reaplicar bloque 4: quitar tarjeta de clima de routines_screen ---
python3 << 'PYEOF'
p = 'lib/routines/routines_screen.dart'
s = open(p, encoding='utf-8').read()
s = s.replace("\nimport '../efficient_climate.dart';", "")
s = s.replace("\n  ClimateMode _climateMode = ClimateMode.auto;", "")
mblock = """  Future<void> _applyClimate() async {
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

"""
s = s.replace(mblock, "")
s = s.replace("""                const SizedBox(height: 8),
                _climateCard(es),
                const SizedBox(height: 8),
                ..._routines.map((r) => _routineCard(r, es)),""",
"""                const SizedBox(height: 8),
                ..._routines.map((r) => _routineCard(r, es)),""")
start = s.find("  Widget _climateCard(bool es) {")
end = s.find("  Widget _routineCard(Routine r, bool es) {")
if start != -1 and end != -1 and start < end:
    s = s[:start] + s[end:]
    print("OK  tarjeta de clima retirada")
else:
    print("AVISO: _climateCard no encontrado (¿ya fuera?)")
open(p,'w',encoding='utf-8').write(s)
PYEOF

# --- 4) KM DEL CICLO en el widget (desde la ultima carga) ---
python3 << 'PYEOF'
import sys
p = 'lib/widget_chart.dart'
s = open(p, encoding='utf-8').read()

# 4a) devolver 'cycleKm' en el mapa de extras
one = ("    'realRange': realRange,", "    'realRange': realRange,\n    'cycleKm': cycleKm,")
if s.count(one[0])!=1: print(f"ERROR extras: x{s.count(one[0])}"); sys.exit(1)
s = s.replace(one[0], one[1])

# 4b) declarar cycleKm junto a realRange
one2 = ("  String realRange = '';", "  String realRange = '';\n  String cycleKm = '';")
if s.count(one2[0])!=1: print(f"ERROR decl: x{s.count(one2[0])}"); sys.exit(1)
s = s.replace(one2[0], one2[1])

# 4c) calcular km desde el inicio de la ultima carga (usa points + validSessions)
anchor = "    final hasData ="
calc = """    // Km recorridos desde el inicio de la ultima carga registrada.
    if (validSessions.isNotEmpty && points.isNotEmpty) {
      final lastStart = validSessions
          .map((x) => x.startTs)
          .reduce((a, x) => a > x ? a : x);
      final after = points.where((pt) => pt.ts >= lastStart).toList();
      if (after.length >= 2) {
        final km = after.last.km - after.first.km;
        if (km > 0) cycleKm = km.toString();
      }
    }

    final hasData ="""
if s.count(anchor)!=1: print(f"ERROR calc: x{s.count(anchor)}"); sys.exit(1)
s = s.replace(anchor, calc)
open(p,'w',encoding='utf-8').write(s)
print("OK  widget_chart.dart: cycleKm calculado")
PYEOF

# 4d) provider Kotlin: mostrar km del ciclo en la linea de autonomia
python3 << 'PYEOF'
import sys
p = 'android/app/src/main/kotlin/com/txurtxil/lpb10/BatteryWidgetProvider.kt'
s = open(p, encoding='utf-8').read()

one = ('        val realRange = prefs.getString("realRange", null)',
       '        val realRange = prefs.getString("realRange", null)\n        val cycleKm = prefs.getString("cycleKm", null)')
if s.count(one[0])!=1: print(f"ERROR kt decl: x{s.count(one[0])}"); sys.exit(1)
s = s.replace(one[0], one[1])

# insertar km del ciclo en el rangeText
old = '''        val rangeText = when {
            range != null && !realRange.isNullOrEmpty() -> "$range km \u00b7 real ~$realRange km"
            range != null -> "$range km autonomia"
            else -> "-- km autonomia"
        }'''
new = '''        val cyclePart = if (!cycleKm.isNullOrEmpty()) "  \u00b7  $cycleKm km ciclo" else ""
        val rangeText = when {
            range != null && !realRange.isNullOrEmpty() -> "$range km \u00b7 real ~$realRange km$cyclePart"
            range != null -> "$range km autonomia$cyclePart"
            else -> "-- km autonomia"
        }'''
if s.count(old)!=1: print(f"ERROR kt rangeText: x{s.count(old)}"); sys.exit(1)
s = s.replace(old, new)
open(p,'w',encoding='utf-8').write(s)
print("OK  provider Kotlin: km del ciclo en la linea")
PYEOF

echo "LISTO. Compila: flutter build apk --release"
