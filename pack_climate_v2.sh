#!/bin/bash
# ============================================================================
# LMB10 - pack_climate_v2.sh  —  Clima permanente + clima como rutina favorita
#
#  Cierra 3 cosas de golpe:
#   1) Clima PERMANENTE: nuevo climateManual (cmd 170) que NO se auto-apaga
#      (a diferencia de prepareCarNow/360 que muere a los ~20 min).
#   2) Selector Preacondicionar / Permanente en la logica de clima eficiente.
#   3) El clima eficiente pasa a ser RUTINA de pleno derecho -> tiene estrella,
#      es FAVORITABLE y por tanto puede ir de boton en el WIDGET (y programarse).
#      Se retira la tarjeta especial de clima; en su lugar hay rutinas preset:
#        - Clima Auto (tiempo)        [preacondiciona]
#        - Clima Verano 23 permanente
#        - Clima Invierno 20 permanente
#
# Ejecutar desde la raiz: bash pack_climate_v2.sh
# ============================================================================
set -e
[ -f lib/main.dart ] || { echo "ERROR: ejecuta desde la raiz del proyecto."; exit 1; }
mkdir -p backups_widget
cp lib/leapmotor_engine.dart backups_widget/leapmotor_engine.dart.bak_climate2
cp lib/efficient_climate.dart backups_widget/efficient_climate.dart.bak_climate2
cp lib/routines/routine_engine.dart backups_widget/routine_engine.dart.bak_climate2
cp lib/routines/routines_screen.dart backups_widget/routines_screen.dart.bak_climate2

# ---------------------------------------------------------------------------
# 1) Engine: climateManual (clima permanente, cmd 170)
# ---------------------------------------------------------------------------
python3 << 'PYEOF'
import sys
p = 'lib/leapmotor_engine.dart'
s = open(p, encoding='utf-8').read()
anchor = "      pin: pin, actionLabel: 'ac_off');"
add = anchor + """

  /// Clima normal PERMANENTE (cmd 170): sigue encendido hasta apagarlo con
  /// acOff. A diferencia de prepareCarNow (360), que se auto-apaga ~20 min.
  /// Mismo formato de payload que quickCool/quickHeat, con temperatura libre.
  Future<void> climateManual(String vin, String pin,
          {required bool heat, required String temperature}) =>
      _remoteControlWithPin(
          vin: vin,
          cmdId: kCmdClimate,
          cmdContent: json.encode({
            'circle': heat ? 'out' : 'in',
            'mode': heat ? 'hot' : 'cold',
            'operate': 'manual',
            'position': 'all',
            'temperature': temperature,
            'windlevel': '5',
            'wshld': '0'
          }),
          pin: pin,
          actionLabel: 'climate_manual');"""
if s.count(anchor)!=1:
    print(f"ERROR engine: ancla x{s.count(anchor)}"); sys.exit(1)
s = s.replace(anchor, add)
open(p,'w',encoding='utf-8').write(s)
print("OK  engine: climateManual (permanente)")
PYEOF

# ---------------------------------------------------------------------------
# 2) efficient_climate.dart: parametro permanent + uso de climateManual
# ---------------------------------------------------------------------------
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
    if s.count(a)!=1: print(f"ERROR sub: x{s.count(a)}: {a[:40]}"); sys.exit(1)
    s = s.replace(a,b)

open(p,'w',encoding='utf-8').write(s)
print("OK  efficient_climate.dart: permanent + helpers")
PYEOF

# ---------------------------------------------------------------------------
# 3) routine_engine.dart: accion efficientClimate + rutinas preset de clima
# ---------------------------------------------------------------------------
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
print("OK  routine_engine.dart: accion + presets de clima")
PYEOF

# ---------------------------------------------------------------------------
# 4) routines_screen.dart: quitar la tarjeta especial de clima (ya son rutinas)
# ---------------------------------------------------------------------------
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
    print("OK  routines_screen.dart: tarjeta de clima retirada")
else:
    print("AVISO: no se encontro _climateCard para retirar")

open(p,'w',encoding='utf-8').write(s)
PYEOF

cat << 'DONE'
============================================================
CLIMA v2 aplicado. Compila:
  flutter build apk --release
============================================================
DONE
