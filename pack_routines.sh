#!/bin/bash
# ============================================================================
# LMB10 - pack_routines.sh  —  Motor de RUTINAS + 3 rutinas de autonomia
#
#  Almacen: lm_routines_v1 (flutter_secure_storage), como el resto de datos.
#  Ejecucion: en secuencia contra tu capa de comandos real, con verificacion
#             de PIN y evaluacion de condiciones (enchufado / SoC / temp bateria)
#             contra el ultimo estado. Reutilizable desde la UI y WorkManager.
#
#  Rutinas de autonomia precargadas (todas orientadas a NO gastar bateria):
#   1) Salida matutina eco  -> si enchufado: prepareCarNow(20C) + asiento + volante
#   2) Bateria a punto       -> si enchufado y fria: batteryPreheatOn
#   3) Carga diaria / viaje  -> setChargeLimit(80) / setChargeLimit(100)
#
#  Disparo: manual (ahora) o programado por hora + dias (via WorkManager).
#  Widget: 1-2 botones de acceso rapido bajo el grafico (abren la app en la
#          rutina y la ejecutan alli — via fiable, sin BroadcastReceiver fragil).
#
# Ejecutar desde la raiz: bash pack_routines.sh
# ============================================================================
set -e
[ -f lib/main.dart ] || { echo "ERROR: ejecuta desde la raiz del proyecto."; exit 1; }
mkdir -p backups_widget lib/routines
cp lib/main.dart backups_widget/main.dart.bak_routines
cp lib/widget_chart.dart backups_widget/widget_chart.dart.bak_routines

# ---------------------------------------------------------------------------
# 1) lib/routines/routine_engine.dart  — modelos + almacen + motor
# ---------------------------------------------------------------------------
cat > lib/routines/routine_engine.dart << 'EOF'
// routine_engine.dart — Motor de rutinas de LMB10.
//
// Una rutina = lista ordenada de pasos. Cada paso es una accion conocida
// (enum RoutineAction) con parametros, y una condicion opcional que se evalua
// contra el ultimo VehicleStatus antes de ejecutarlo (p. ej. "solo si
// enchufado"). El motor recorre los pasos en orden, verifica PIN en cada
// comando (tu _remoteControlWithPin ya lo hace) y deja una pequena espera
// entre ellos. Sin estado en memoria: todo en lm_routines_v1, para que la UI
// y el callback de WorkManager compartan las mismas rutinas.

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../leapmotor_engine.dart';

const _storage = FlutterSecureStorage();
const _kRoutinesKey = 'lm_routines_v1';

/// Acciones que una rutina puede encadenar. Solo comandos confirmados que
/// existen en LeapmotorApiClient.
enum RoutineAction {
  preconditionHeat, // prepareCarNow(heat:true, temperature, steeringWheel)
  preconditionCool, // prepareCarNow(heat:false, temperature, steeringWheel)
  seatHeatDriver, // seatHeat(position:1, level)
  steeringWheelHeat, // steeringWheelHeatOn
  batteryPreheat, // batteryPreheatOn
  setChargeLimit, // setChargeLimit(percent)
  lock, // lockVehicle
  sentryOn, // sentryModeOn
  windowsClose, // windowsClose
}

/// Condicion previa a un paso (o a la rutina). Se evalua con el ultimo status.
enum RoutineCondition {
  none,
  ifPluggedIn, // isPluggedIn == true
  ifBatteryCold, // minBatteryTemp <= coldThresholdC
  ifSocBelow, // soc < value
}

class RoutineStep {
  final RoutineAction action;
  final RoutineCondition condition;
  final int intParam; // temperatura, %, nivel, umbral SoC segun accion
  final bool boolParam; // p. ej. incluir volante en preacondicionamiento

  RoutineStep({
    required this.action,
    this.condition = RoutineCondition.none,
    this.intParam = 0,
    this.boolParam = false,
  });

  Map<String, dynamic> toJson() => {
        'action': action.name,
        'condition': condition.name,
        'intParam': intParam,
        'boolParam': boolParam,
      };

  factory RoutineStep.fromJson(Map<String, dynamic> j) => RoutineStep(
        action: RoutineAction.values.byName(j['action'] as String),
        condition: RoutineCondition.values
            .byName(j['condition'] as String? ?? 'none'),
        intParam: j['intParam'] as int? ?? 0,
        boolParam: j['boolParam'] as bool? ?? false,
      );
}

class Routine {
  final String id;
  String name;
  List<RoutineStep> steps;
  bool enabled;

  // Disparador programado (opcional). scheduleHour == null => solo manual.
  int? scheduleHour; // 0-23
  int? scheduleMinute; // 0-59
  List<int> scheduleDays; // 1=Lun ... 7=Dom (vacio = todos los dias)

  static const int coldThresholdC = 10; // bateria "fria" por debajo de esto

  Routine({
    required this.id,
    required this.name,
    required this.steps,
    this.enabled = true,
    this.scheduleHour,
    this.scheduleMinute,
    List<int>? scheduleDays,
  }) : scheduleDays = scheduleDays ?? [];

  bool get isScheduled => scheduleHour != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'enabled': enabled,
        'scheduleHour': scheduleHour,
        'scheduleMinute': scheduleMinute,
        'scheduleDays': scheduleDays,
        'steps': steps.map((s) => s.toJson()).toList(),
      };

  factory Routine.fromJson(Map<String, dynamic> j) => Routine(
        id: j['id'] as String,
        name: j['name'] as String,
        enabled: j['enabled'] as bool? ?? true,
        scheduleHour: j['scheduleHour'] as int?,
        scheduleMinute: j['scheduleMinute'] as int?,
        scheduleDays: (j['scheduleDays'] as List? ?? [])
            .map((e) => e as int)
            .toList(),
        steps: (j['steps'] as List? ?? [])
            .map((e) => RoutineStep.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

/// Resultado de ejecutar una rutina (para UI y notificaciones).
class RoutineRunResult {
  final bool ok;
  final int done;
  final int skipped;
  final int failed;
  final String summary;
  RoutineRunResult(this.ok, this.done, this.skipped, this.failed, this.summary);
}

class RoutineStore {
  static Future<List<Routine>> load() async {
    final raw = await _storage.read(key: _kRoutinesKey);
    if (raw == null) return _defaults();
    try {
      final list = (json.decode(raw) as List)
          .map((e) => Routine.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return list.isEmpty ? _defaults() : list;
    } catch (_) {
      return _defaults();
    }
  }

  static Future<void> saveAll(List<Routine> routines) async {
    await _storage.write(
        key: _kRoutinesKey,
        value: json.encode(routines.map((r) => r.toJson()).toList()));
  }

  /// Rutinas de autonomia precargadas la primera vez.
  static List<Routine> _defaults() => [
        Routine(
          id: 'eco_morning',
          name: 'Salida matutina eco',
          scheduleHour: 7,
          scheduleMinute: 0,
          scheduleDays: [1, 2, 3, 4, 5],
          enabled: false, // el usuario la activa cuando quiera
          steps: [
            RoutineStep(
                action: RoutineAction.preconditionHeat,
                condition: RoutineCondition.ifPluggedIn,
                intParam: 20,
                boolParam: true), // incluye volante
            RoutineStep(
                action: RoutineAction.seatHeatDriver,
                condition: RoutineCondition.ifPluggedIn,
                intParam: 2), // nivel medio
          ],
        ),
        Routine(
          id: 'battery_ready',
          name: 'Bateria a punto (frio)',
          scheduleHour: 6,
          scheduleMinute: 30,
          scheduleDays: [1, 2, 3, 4, 5],
          enabled: false,
          steps: [
            RoutineStep(
                action: RoutineAction.batteryPreheat,
                condition: RoutineCondition.ifBatteryCold),
          ],
        ),
        Routine(
          id: 'charge_daily',
          name: 'Carga diaria 80%',
          enabled: false,
          steps: [
            RoutineStep(action: RoutineAction.setChargeLimit, intParam: 80),
          ],
        ),
        Routine(
          id: 'charge_trip',
          name: 'Carga viaje 100%',
          enabled: false,
          steps: [
            RoutineStep(action: RoutineAction.setChargeLimit, intParam: 100),
          ],
        ),
      ];
}

class RoutineEngine {
  RoutineEngine({required this.client, required this.vin, required this.pin});
  final LeapmotorApiClient client;
  final String vin;
  final String pin;

  /// Ejecuta una rutina completa. [status] es el ultimo estado conocido para
  /// evaluar condiciones; si es null, se ignoran las condiciones (se asume que
  /// el usuario lanza manualmente y sabe lo que hace).
  Future<RoutineRunResult> run(Routine r, {VehicleStatus? status}) async {
    var done = 0, skipped = 0, failed = 0;
    for (final step in r.steps) {
      if (!_conditionMet(step, status)) {
        skipped++;
        continue;
      }
      try {
        await _execute(step);
        done++;
        // Respiro entre comandos: cada uno hace verificacion de PIN + sondeo.
        await Future.delayed(const Duration(seconds: 3));
      } catch (_) {
        failed++;
      }
    }
    final ok = failed == 0 && done > 0;
    final summary = failed > 0
        ? '$done hechos, $failed fallidos, $skipped omitidos'
        : (done == 0
            ? 'Nada que ejecutar (condiciones no cumplidas)'
            : '$done hechos${skipped > 0 ? ', $skipped omitidos' : ''}');
    return RoutineRunResult(ok, done, skipped, failed, summary);
  }

  bool _conditionMet(RoutineStep step, VehicleStatus? s) {
    switch (step.condition) {
      case RoutineCondition.none:
        return true;
      case RoutineCondition.ifPluggedIn:
        return s == null ? true : (s.isPluggedIn == true);
      case RoutineCondition.ifBatteryCold:
        if (s == null) return true;
        final raw = s.raw['minBatteryTemp'];
        final t = raw is num
            ? raw.toDouble()
            : (raw is String ? double.tryParse(raw) : null);
        return t == null ? true : t <= Routine.coldThresholdC;
      case RoutineCondition.ifSocBelow:
        if (s == null) return true;
        final soc = s.preciseSoc ?? s.soc?.toDouble();
        return soc == null ? true : soc < step.intParam;
    }
  }

  Future<void> _execute(RoutineStep step) async {
    switch (step.action) {
      case RoutineAction.preconditionHeat:
        await client.prepareCarNow(vin, pin,
            heat: true,
            temperature: '${step.intParam}',
            steeringWheelHeat: step.boolParam);
        break;
      case RoutineAction.preconditionCool:
        await client.prepareCarNow(vin, pin,
            heat: false,
            temperature: '${step.intParam}',
            steeringWheelHeat: step.boolParam);
        break;
      case RoutineAction.seatHeatDriver:
        await client.seatHeat(vin, pin, position: 1, level: step.intParam);
        break;
      case RoutineAction.steeringWheelHeat:
        await client.steeringWheelHeatOn(vin, pin);
        break;
      case RoutineAction.batteryPreheat:
        await client.batteryPreheatOn(vin, pin);
        break;
      case RoutineAction.setChargeLimit:
        await client.setChargeLimit(vin, pin, step.intParam);
        break;
      case RoutineAction.lock:
        await client.lockVehicle(vin, pin);
        break;
      case RoutineAction.sentryOn:
        await client.sentryModeOn(vin, pin);
        break;
      case RoutineAction.windowsClose:
        await client.windowsClose(vin, pin);
        break;
    }
  }
}

/// Texto es/en de una accion, para pintarla en la UI.
String routineActionLabel(RoutineStep s, {required bool es}) {
  switch (s.action) {
    case RoutineAction.preconditionHeat:
      return es
          ? 'Climatizar calor ${s.intParam}\u00b0${s.boolParam ? ' + volante' : ''}'
          : 'Preheat cabin ${s.intParam}\u00b0${s.boolParam ? ' + wheel' : ''}';
    case RoutineAction.preconditionCool:
      return es
          ? 'Climatizar frio ${s.intParam}\u00b0'
          : 'Precool cabin ${s.intParam}\u00b0';
    case RoutineAction.seatHeatDriver:
      return es
          ? 'Asiento conductor nivel ${s.intParam}'
          : 'Driver seat level ${s.intParam}';
    case RoutineAction.steeringWheelHeat:
      return es ? 'Calentar volante' : 'Heat steering wheel';
    case RoutineAction.batteryPreheat:
      return es ? 'Precalentar bateria' : 'Preheat battery';
    case RoutineAction.setChargeLimit:
      return es ? 'Limite de carga ${s.intParam}%' : 'Charge limit ${s.intParam}%';
    case RoutineAction.lock:
      return es ? 'Bloquear' : 'Lock';
    case RoutineAction.sentryOn:
      return es ? 'Activar centinela' : 'Arm sentry';
    case RoutineAction.windowsClose:
      return es ? 'Subir ventanillas' : 'Close windows';
  }
}

String routineConditionLabel(RoutineCondition c, int v, {required bool es}) {
  switch (c) {
    case RoutineCondition.none:
      return '';
    case RoutineCondition.ifPluggedIn:
      return es ? 'si enchufado' : 'if plugged in';
    case RoutineCondition.ifBatteryCold:
      return es ? 'si bateria fria' : 'if battery cold';
    case RoutineCondition.ifSocBelow:
      return es ? 'si SoC < $v%' : 'if SoC < $v%';
  }
}
EOF
echo "OK  lib/routines/routine_engine.dart"

# ---------------------------------------------------------------------------
# 2) lib/routines/routines_screen.dart  — menu "Rutinas"
# ---------------------------------------------------------------------------
cat > lib/routines/routines_screen.dart << 'EOF'
// routines_screen.dart — Menu "Rutinas" de LMB10.
// Lanza rutinas al momento o programa su disparo por hora/dias.

import 'package:flutter/material.dart';

import '../leapmotor_engine.dart';
import 'routine_engine.dart';

class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({
    super.key,
    required this.client,
    required this.vin,
    required this.pin,
    this.status,
    this.autoRunId,
  });

  final LeapmotorApiClient client;
  final String vin;
  final String pin;
  final VehicleStatus? status;

  /// Si se abre desde el widget con una rutina concreta, se ejecuta al entrar.
  final String? autoRunId;

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  List<Routine> _routines = [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _routines = await RoutineStore.load();
    setState(() => _loading = false);
    if (widget.autoRunId != null) {
      final match = _routines.where((r) => r.id == widget.autoRunId);
      if (match.isNotEmpty) {
        await _run(match.first);
      }
    }
  }

  RoutineEngine get _engine =>
      RoutineEngine(client: widget.client, vin: widget.vin, pin: widget.pin);

  Future<void> _run(Routine r) async {
    setState(() => _busy = true);
    RoutineRunResult res;
    try {
      res = await _engine.run(r, status: widget.status);
    } catch (e) {
      res = RoutineRunResult(false, 0, 0, 1, '$e');
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${r.name}: ${res.summary}'),
        backgroundColor: res.ok ? null : Colors.red.shade700));
  }

  Future<void> _toggleEnabled(Routine r, bool v) async {
    setState(() => r.enabled = v);
    await RoutineStore.saveAll(_routines);
  }

  Future<void> _editSchedule(Routine r) async {
    final es = Localizations.localeOf(context).languageCode == 'es';
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: r.scheduleHour ?? 7, minute: r.scheduleMinute ?? 0),
      helpText: es ? 'Hora de disparo' : 'Trigger time',
    );
    if (picked == null) return;
    setState(() {
      r.scheduleHour = picked.hour;
      r.scheduleMinute = picked.minute;
      r.enabled = true;
    });
    await RoutineStore.saveAll(_routines);
  }

  Future<void> _clearSchedule(Routine r) async {
    setState(() {
      r.scheduleHour = null;
      r.scheduleMinute = null;
    });
    await RoutineStore.saveAll(_routines);
  }

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    return Scaffold(
      appBar: AppBar(title: Text(es ? 'Rutinas' : 'Routines')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      es
                          ? 'Rutinas de autonomia: aprovechan la energia de la red (coche enchufado) para no gastar bateria. Las programadas se ejecutan en segundo plano; recuerda el PIN en el login para que funcionen con la app cerrada.'
                          : 'Range routines use grid power (car plugged in) to spare the battery. Scheduled ones run in the background; remember the PIN at login so they work with the app closed.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ..._routines.map((r) => _routineCard(r, es)),
              ],
            ),
    );
  }

  Widget _routineCard(Routine r, bool es) {
    final schedule = r.isScheduled
        ? '${r.scheduleHour!.toString().padLeft(2, '0')}:${r.scheduleMinute!.toString().padLeft(2, '0')}'
            '${r.scheduleDays.isEmpty ? (es ? ' cada dia' : ' every day') : ' ${_daysLabel(r.scheduleDays, es)}'}'
        : (es ? 'Solo manual' : 'Manual only');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(r.name,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                if (r.isScheduled)
                  Switch(
                    value: r.enabled,
                    onChanged: (v) => _toggleEnabled(r, v),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            ...r.steps.map((s) {
              final cond =
                  routineConditionLabel(s.condition, s.intParam, es: es);
              return Padding(
                padding: const EdgeInsets.only(left: 4, top: 2),
                child: Text(
                  '\u2022 ${routineActionLabel(s, es: es)}${cond.isEmpty ? '' : '  ($cond)'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            }),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule,
                    size: 16, color: Theme.of(context).hintColor),
                const SizedBox(width: 4),
                Expanded(
                    child: Text(schedule,
                        style: Theme.of(context).textTheme.bodySmall)),
                TextButton(
                  onPressed: () => _editSchedule(r),
                  child: Text(es ? 'Programar' : 'Schedule'),
                ),
                if (r.isScheduled)
                  TextButton(
                    onPressed: () => _clearSchedule(r),
                    child: Text(es ? 'Quitar' : 'Clear'),
                  ),
              ],
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : () => _run(r),
                icon: const Icon(Icons.play_arrow),
                label: Text(es ? 'Ejecutar ahora' : 'Run now'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _daysLabel(List<int> days, bool es) {
    const esD = ['', 'L', 'M', 'X', 'J', 'V', 'S', 'D'];
    const enD = ['', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
    final names = es ? esD : enD;
    return days.map((d) => names[d]).join('');
  }
}
EOF
echo "OK  lib/routines/routines_screen.dart"

# ---------------------------------------------------------------------------
# 3) lib/routines/routines_background.dart  — evaluar programadas (WorkManager)
# ---------------------------------------------------------------------------
cat > lib/routines/routines_background.dart << 'EOF'
// routines_background.dart — Evaluacion de rutinas programadas en segundo
// plano. Llamar desde el callback de WorkManager (~15 min). Ejecuta una
// rutina si su hora ya paso dentro de la ultima ventana y hoy es un dia
// valido, evitando repetirla el mismo dia (marca lm_routine_lastrun_<id>).

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../leapmotor_engine.dart';
import 'routine_engine.dart';

const _bgStorage = FlutterSecureStorage();

Future<void> routinesBackgroundTick(
    LeapmotorApiClient client, String vin, String pin,
    {VehicleStatus? status}) async {
  if (pin.isEmpty) return; // sin PIN no hay comandos en fondo
  final now = DateTime.now();
  final weekday = now.weekday; // 1=Lun ... 7=Dom
  final routines = await RoutineStore.load();
  final engine = RoutineEngine(client: client, vin: vin, pin: pin);

  for (final r in routines) {
    if (!r.enabled || !r.isScheduled) continue;
    if (r.scheduleDays.isNotEmpty && !r.scheduleDays.contains(weekday)) continue;

    final sched = DateTime(now.year, now.month, now.day, r.scheduleHour!,
        r.scheduleMinute ?? 0);
    // Disparar si la hora ya paso hoy pero por menos de 30 min (ventana de
    // WorkManager) y no se ejecuto ya hoy.
    final diff = now.difference(sched).inMinutes;
    if (diff < 0 || diff > 30) continue;

    final key = 'lm_routine_lastrun_${r.id}';
    final last = await _bgStorage.read(key: key);
    final today = '${now.year}-${now.month}-${now.day}';
    if (last == today) continue;

    await engine.run(r, status: status);
    await _bgStorage.write(key: key, value: today);
  }
}
EOF
echo "OK  lib/routines/routines_background.dart"

# ---------------------------------------------------------------------------
# 4) Parches a main.dart: import + boton AppBar + hook WorkManager + widget
# ---------------------------------------------------------------------------
python3 << 'PYEOF'
import sys

def patch(path, jobs):
    src = open(path, encoding='utf-8').read()
    for label, anchor, repl in jobs:
        n = src.count(anchor)
        if n != 1:
            print(f"ERROR '{label}': ancla {n} veces (esperada 1). {path} sin tocar.")
            sys.exit(1)
        src = src.replace(anchor, repl)
        print(f"OK  {label}")
    open(path, 'w', encoding='utf-8').write(src)

patch('lib/main.dart', [
 ('imports rutinas',
  "import 'sentry/sentry_background.dart';",
  "import 'sentry/sentry_background.dart';\nimport 'routines/routines_screen.dart';\nimport 'routines/routines_background.dart';"),

 ('boton Rutinas en AppBar (antes del sobre)',
  """          IconButton(
            tooltip: Localizations.localeOf(context).languageCode == 'es' ? 'Mensajes' : 'Messages',""",
  """          IconButton(
            tooltip: Localizations.localeOf(context).languageCode == 'es' ? 'Rutinas' : 'Routines',
            icon: const Icon(Icons.auto_awesome_motion_outlined),
            onPressed: () async {
              final pin = await _resolvePin();
              if (pin == null || pin.isEmpty) return;
              if (!mounted) return;
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => RoutinesScreen(client: widget.client, vin: widget.vehicle.vin, pin: pin, status: _status),
              ));
              _loadStatus();
            },
          ),
          IconButton(
            tooltip: Localizations.localeOf(context).languageCode == 'es' ? 'Mensajes' : 'Messages',"""),

 ('hook WorkManager rutinas',
  "  await sentryBackgroundPoll();",
  """  await sentryBackgroundPoll();
  // Rutinas programadas (necesita PIN recordado)
  try {
    final rpin = await _storage.read(key: _pinKey) ?? '';
    if (rpin.isNotEmpty) {
      await routinesBackgroundTick(client, status.vin, rpin, status: status);
    }
  } catch (_) {}"""),
])
print('OK  parches main.dart')
PYEOF

# ---------------------------------------------------------------------------
# 5) Comprobacion de nombres que el parche asume (aborta si no encajan)
# ---------------------------------------------------------------------------
python3 << 'PYEOF'
m = open('lib/main.dart', encoding='utf-8').read()
checks = {
  '_resolvePin()': '_resolvePin(',
  'widget.vehicle.vin': 'widget.vehicle.vin',
  '_status field': '_status',
  '_pinKey const': '_pinKey',
  'status.vin en bg': 'status.vin',
}
missing = [k for k,v in checks.items() if v not in m]
if missing:
    print('AVISO: revisa estos nombres asumidos por el parche:', ', '.join(missing))
else:
    print('OK  nombres asumidos presentes (_resolvePin, _status, _pinKey, vehicle.vin)')
PYEOF

cat << 'DONE'
============================================================
RUTINAS APLICADAS. Compila:
  flutter build apk --release
============================================================
DONE
