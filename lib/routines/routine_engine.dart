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
import '../efficient_climate.dart';

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
  efficientClimate, // clima eficiente (intParam=modo, boolParam=permanente)
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
  bool favorite;

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
    this.favorite = false,
    this.scheduleHour,
    this.scheduleMinute,
    List<int>? scheduleDays,
  }) : scheduleDays = scheduleDays ?? [];

  bool get isScheduled => scheduleHour != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'enabled': enabled,
        'favorite': favorite,
        'scheduleHour': scheduleHour,
        'scheduleMinute': scheduleMinute,
        'scheduleDays': scheduleDays,
        'steps': steps.map((s) => s.toJson()).toList(),
      };

  factory Routine.fromJson(Map<String, dynamic> j) => Routine(
        id: j['id'] as String,
        name: j['name'] as String,
        enabled: j['enabled'] as bool? ?? true,
        favorite: j['favorite'] as bool? ?? false,
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
      if (list.isEmpty) return _defaults();
      // Migracion: añadir presets nuevos (p. ej. rutinas de clima) que aun no
      // esten en la lista guardada, sin tocar las existentes ni sus favoritas.
      final ids = list.map((r) => r.id).toSet();
      var changed = false;
      for (final d in _defaults()) {
        if (!ids.contains(d.id)) {
          list.add(d);
          changed = true;
        }
      }
      if (changed) await saveAll(list);
      return list;
    } catch (_) {
      return _defaults();
    }
  }

  static Future<void> saveAll(List<Routine> routines) async {
    await _storage.write(
        key: _kRoutinesKey,
        value: json.encode(routines.map((r) => r.toJson()).toList()));
  }

  /// Devuelve hasta 2 rutinas marcadas como favoritas, en orden.
  static Future<List<Routine>> favorites() async {
    final all = await load();
    return all.where((r) => r.favorite).take(2).toList();
  }

  /// Rutinas de autonomia precargadas la primera vez.
  static List<Routine> _defaults() => [
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
  VehicleStatus? _runStatus;
  Future<RoutineRunResult> run(Routine r, {VehicleStatus? status}) async {
    _runStatus = status;
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
    case RoutineAction.efficientClimate:
      final mode = ClimateMode.values[s.intParam.clamp(0, ClimateMode.values.length - 1)];
      final tail = s.boolParam ? (es ? ' permanente' : ' permanent') : (es ? ' preacond.' : ' precond.');
      return (es ? 'Clima ' : 'Climate ') + climateModeLabel(mode, es: es) + tail;
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
