import 'dart:async';
import 'dart:ui' show DartPluginRegistrant;
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:latlong2/latlong.dart';

import 'package:home_widget/home_widget.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as plain_http;
import 'package:url_launcher/url_launcher.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'leapmotor_engine.dart';
import 'about_screen.dart';
import 'guard_mode_screen.dart';
import 'sentry/sentry_screen.dart';
import 'sentry/sentry_background.dart';
import 'routines/routines_screen.dart';
import 'routines/routines_background.dart';
import 'routines/routine_engine.dart';
import 'preconditioning_screen.dart';
import 'messages_screen.dart';
import 'charge_schedule_screen.dart';
import 'settings_screen.dart';
import 'backup_helper.dart';
import 'ticket_screen.dart';
import 'efficiency_coach.dart';
import 'widget_chart.dart';
import 'history_archive.dart';
import 'l10n/generated/app_localizations.dart';
import 'cert_store.dart';
import 'cert_import_screen.dart';
import 'welcome_screen.dart';
import 'daily_stats.dart';
import 'energy_cost.dart';
import 'charge_cost.dart';
import 'car_log_bridge.dart';
import 'vehicle_profile.dart';
import 'maintenance.dart';

const _storage = FlutterSecureStorage();

String? gPendingRoutineId;
void Function()? gOnRoutinePending;
String? _routineIdFromUri(Uri? uri) {
  if (uri == null) return null;
  if (uri.scheme != 'lmb10') return null;
  if (uri.host != 'routine' && uri.path != 'routine') return null;
  final id = uri.queryParameters['id'];
  return (id != null && id.isNotEmpty) ? id : null;
}
const _sessionKey = 'lm_session_v1';
const _pinKey = 'lm_pin_v1';
const _vinKey = 'lm_vin_v1';


/// Logica compartida de refresco: restaura sesion, consulta estado, actualiza
/// historiales locales y empuja datos al widget. La usan tanto el Dashboard
/// (primer plano) como el callback de fondo de WorkManager.
Future<void> refreshVehicleDataInBackground() async {
  if (!await hasClientCert()) return;
  final raw = await _storage.read(key: _sessionKey);
  if (raw == null) return;
  final sessionMap = Map<String, String>.from(json.decode(raw) as Map);
  final session = SessionData.fromMap(sessionMap);

  final staticClient = await createStaticClient();
  final client = LeapmotorApiClient(staticClient);
  await client.restoreSession(session);

  final vehicles = await client.getVehicleList();
  if (vehicles.isEmpty) return;
  final savedVin = await _storage.read(key: _vinKey);
  final vehicle = vehicles.firstWhere((v) => v.vin == savedVin, orElse: () => vehicles.first);

  final status = await client.getVehicleStatus(vehicle.vin);

  await _pushToHomeWidget(status);

  // Deteccion de cargas/consumo tambien en segundo plano (misma logica que en el Dashboard)
  final histRaw = await _storage.read(key: 'lm_bg_prev_charging_v1');
  final wasCharging = histRaw == '1';
  final soc = status.preciseSoc ?? status.soc?.toDouble();
  await ChargeHistoryStore.reconcileOpenSession(
    isPluggedIn: status.isPluggedIn,
    chargeCompleted: status.chargeCompleted == true,
    currentSoc: soc,
  );
  if (soc != null) {
    if (!wasCharging && status.isCharging) {
      await ChargeHistoryStore.startSession(soc);
    } else if (wasCharging && !status.isCharging) {
      await ChargeHistoryStore.endSession(soc);
    }
    if (status.totalMileage != null && !status.isCharging) {
      await TripPointStore.addPoint(status.totalMileage!, soc);
    }
  }
  await _storage.write(key: 'lm_bg_prev_charging_v1', value: status.isCharging ? '1' : '0');
  await checkAndNotifyStateChanges(status);
  await sentryBackgroundPoll();
  // Rutinas programadas (necesita PIN recordado)
  try {
    final rpin = await _storage.read(key: _pinKey) ?? '';
    final rvin = await _storage.read(key: _vinKey) ?? '';
    if (rpin.isNotEmpty && rvin.isNotEmpty) {
      await routinesBackgroundTick(client, rvin, rpin, status: status);
    }
  } catch (_) {}

  // Token puede haber caducado entre refrescos; si getVehicleStatus lo maneja
  // internamente via withTokenRetry, no hace falta nada mas aqui. Si el refresh
  // devolvio un token nuevo, lo persistimos para que el siguiente ciclo lo use.
  try {
    final updatedSession = client.exportSession();
    await _storage.write(key: _sessionKey, value: json.encode(updatedSession.toMap()));
  } catch (_) {
    // Si exportSession falla (sesion incompleta), no se actualiza; se reintentara la proxima vez.
  }
}

@pragma('vm:entry-point')
void backgroundCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await refreshVehicleDataInBackground();
      // Copia de seguridad automatica diaria (best-effort).
      await BackupHelper.autoBackupIfDue(
        (k) => _storage.read(key: k),
        (k, v) => _storage.write(key: k, value: v),
      );
      return true;
    } catch (_) {
      return false;
    }
  });
}

// ============================================================
// Android Auto: motor Dart headless invocado desde CarAppService.
// La pantalla del coche no puede hablar mTLS/HMAC en Kotlin, asi que
// reutiliza este entrypoint para ejecutar el codigo Dart existente.
// ============================================================
@pragma('vm:entry-point')
void carAppMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadVehicleProfile();
  DartPluginRegistrant.ensureInitialized();
  const carChannel = MethodChannel('lmb10/carapp');
  carChannel.setMethodCallHandler((call) async {
    try {
      switch (call.method) {
        case 'refresh':
          await refreshVehicleDataInBackground();
          return true;
        case 'runRoutine':
          final args = Map<String, dynamic>.from(call.arguments as Map);
          final id = args['id'] as String?;
          if (id == null || id.isEmpty) return '';
          return await carRunRoutineById(id);
        case 'quickAction':
          final args = Map<String, dynamic>.from(call.arguments as Map);
          final action = args['action'] as String?;
          if (action == null || action.isEmpty) return false;
          return await carQuickAction(action);
      }
    } catch (_) {
      return false;
    }
    return false;
  });
  // Avisa a Kotlin de que el handler ya esta puesto; hasta entonces
  // la cola del CarBridge retiene los toques del usuario.
  try {
    await carChannel.invokeMethod('ready');
  } catch (_) {}
}

/// Ejecuta una rutina por id sin UI. Reutiliza RoutineEngine, que ya es
/// headless (lo usa routinesBackgroundTick desde WorkManager).
@pragma('vm:entry-point')
Future<String> carRunRoutineById(String id) async {
  final raw = await _storage.read(key: _sessionKey);
  if (raw == null) return '';
  final vin = await _storage.read(key: _vinKey) ?? '';
  final pin = await _storage.read(key: _pinKey) ?? '';
  if (vin.isEmpty || pin.isEmpty) return '';
  final routines = await RoutineStore.load();
  Routine? target;
  for (final r in routines) {
    if (r.id == id) {
      target = r;
      break;
    }
  }
  if (target == null) return '';
  try {
    final sessionMap = Map<String, String>.from(json.decode(raw) as Map);
    final session = SessionData.fromMap(sessionMap);
    final staticClient = await createStaticClient();
    final client = LeapmotorApiClient(staticClient);
    await client.restoreSession(session);
    final engine = RoutineEngine(client: client, vin: vin, pin: pin);
    final res = await engine.run(target);
    // Devuelve "done/total" para que el coche muestre "2 de 3" en vez de "hecho" a ciegas
    final total = res.done + res.failed + res.skipped;
    return '${res.done}/$total';
  } catch (_) {
    return '';
  }
}

/// Ejecuta un comando directo (accion rapida) desde el coche, sin UI.
/// Reutiliza el mismo patron de cliente que carRunRoutineById.
@pragma('vm:entry-point')
/// Motivo del ultimo fallo de carQuickAction, en lenguaje llano.
///
/// La funcion devolvia false en cuatro sitios distintos y desde fuera todos se
/// veian igual, asi que el widget solo podia decir "ERROR". Con el coche en un
/// garaje sin cobertura eso parece que la app esta rota, cuando lo unico que
/// pasa es que el coche no es alcanzable.
String gQuickActionError = '';

String _motivoFallo(Object e) {
  final m = e.toString();
  if (m.contains('Error 71') || m.contains('Poor vehicle network')) {
    return 'Sin cobertura';
  }
  if (m.contains('Error 40') || m.contains('No such permission')) {
    return 'No disponible';
  }
  if (m.contains('Not logged in') || m.contains('token')) return 'Sesion caducada';
  if (m.contains('SocketException') || m.contains('TimeoutException')) {
    return 'Sin conexion';
  }
  return 'Error';
}

Future<bool> carQuickAction(String action) async {
  gQuickActionError = '';
  final raw = await _storage.read(key: _sessionKey);
  if (raw == null) {
    gQuickActionError = 'Sin sesion';
    return false;
  }
  final vin = await _storage.read(key: _vinKey) ?? '';
  final pin = await _storage.read(key: _pinKey) ?? '';
  if (vin.isEmpty || pin.isEmpty) {
    gQuickActionError = 'Falta el PIN';
    return false;
  }
  try {
    final sessionMap = Map<String, String>.from(json.decode(raw) as Map);
    final session = SessionData.fromMap(sessionMap);
    final staticClient = await createStaticClient();
    final c = LeapmotorApiClient(staticClient);
    await c.restoreSession(session);
    switch (action) {
      case 'lock':          await c.lockVehicle(vin, pin); break;
      case 'unlock':        await c.unlockVehicle(vin, pin); break;
      case 'heat':          await c.quickHeat(vin, pin); break;
      case 'cool':          await c.quickCool(vin, pin); break;
      case 'defrost':       await c.windshieldDefrost(vin, pin); break;
      case 'find':          await c.findVehicle(vin, pin); break;
      case 'trunk':         await c.openTrunk(vin, pin); break;
      case 'trunk_close':   await c.closeTrunk(vin, pin); break;
      case 'sentry_on':     await c.sentryModeOn(vin, pin); break;
      case 'sentry_off':    await c.sentryModeOff(vin, pin); break;
      case 'preheat':       await c.batteryPreheatOn(vin, pin); break;
      case 'preheat_off':   await c.batteryPreheatOff(vin, pin); break;
      case 'wheel_heat':    await c.steeringWheelHeatOn(vin, pin); break;
      case 'charger_unlock': await c.unlockCharger(vin, pin); break;
      case 'openall':
        // En serie y con pausa: dos comandos simultaneos el coche los encola mal.
        await c.openTrunk(vin, pin);
        await Future.delayed(const Duration(milliseconds: 1200));
        await c.unlockVehicle(vin, pin);
        break;
      default:
        await CarLogBridge.log('quickAction desconocida: $action');
        gQuickActionError = 'Accion desconocida';
        return false;
    }
    await CarLogBridge.log('quickAction OK: $action');
    return true;
  } catch (e) {
    await CarLogBridge.log('quickAction FALLO $action: $e');
    gQuickActionError = _motivoFallo(e);
    return false;
  }
}



// ============================================================
// Notificaciones locales: bateria baja, carga completa, coche
// desbloqueado inesperadamente, y aviso de coche abierto olvidado.
// ============================================================
const _notifStateKey = 'lm_notif_state_v1';
const _lastManualUnlockKey = 'lm_last_manual_unlock_ts';
const _lowBatteryThreshold = 20.0;
const _unlockedReminderMinutes = 15;

Future<FlutterLocalNotificationsPlugin> _initNotifications() async {
  final plugin = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  await plugin.initialize(settings: const InitializationSettings(android: androidInit));
  final androidImpl = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await androidImpl?.requestNotificationsPermission();
  return plugin;
}

Future<void> _showNotification(FlutterLocalNotificationsPlugin plugin, int id, String title, String body) async {
  const details = NotificationDetails(
    android: AndroidNotificationDetails('lpb10_alerts', 'Alertas del vehiculo', importance: Importance.high, priority: Priority.high),
  );
  await plugin.show(id: id, title: title, body: body, notificationDetails: details);
}

/// Marca que el ultimo bloqueo/desbloqueo lo hizo el usuario desde esta app,
/// para no notificar "desbloqueo inesperado" cuando ha sido el propio usuario.
Future<void> markManualLockAction() async {
  await _storage.write(key: _lastManualUnlockKey, value: DateTime.now().millisecondsSinceEpoch.toString());
}

Future<void> checkAndNotifyStateChanges(VehicleStatus status) async {
  final plugin = await _initNotifications();

  Map<String, dynamic> prevState = {};
  final raw = await _storage.read(key: _notifStateKey);
  if (raw != null) {
    try {
      prevState = Map<String, dynamic>.from(json.decode(raw) as Map);
    } catch (_) {}
  }

  final soc = status.preciseSoc ?? status.soc?.toDouble();
  final prevLocked = prevState['isLocked'] as bool?;
  final prevChargeCompleted = prevState['chargeCompleted'] as bool?;
  var lowBatteryNotified = prevState['lowBatteryNotified'] as bool? ?? false;
  var unlockedSinceTs = prevState['unlockedSinceTs'] as int?;
  var unlockReminderSent = prevState['unlockReminderSent'] as bool? ?? false;

  // -- 1) Bateria baja (con histeresis para no repetir en cada ciclo) --
  if (soc != null) {
    if (soc <= _lowBatteryThreshold && !lowBatteryNotified) {
      await _showNotification(plugin, 1001, 'Bateria baja', 'Tu Leapmotor esta al ${soc.toStringAsFixed(0)}%.');
      lowBatteryNotified = true;
    } else if (soc > _lowBatteryThreshold + 5) {
      lowBatteryNotified = false; // se rearma al subir claramente por encima del umbral
    }
  }

  // -- 2) Carga completada --
  if (status.chargeCompleted == true && prevChargeCompleted != true) {
    await _showNotification(plugin, 1002, 'Carga completada', 'Tu Leapmotor ha terminado de cargar (${soc?.toStringAsFixed(0) ?? '--'}%).');
  }

  // -- 3) Desbloqueo inesperado (no iniciado desde esta app en los ultimos 5 min) --
  if (prevLocked == true && status.isLocked == false) {
    final lastManualRaw = await _storage.read(key: _lastManualUnlockKey);
    final lastManualTs = lastManualRaw != null ? int.tryParse(lastManualRaw) : null;
    final withinGrace = lastManualTs != null && (DateTime.now().millisecondsSinceEpoch - lastManualTs) < 5 * 60 * 1000;
    if (!withinGrace) {
      await _showNotification(plugin, 1003, 'Vehiculo desbloqueado', 'Tu Leapmotor se ha desbloqueado y no fue desde esta app.');
    }
  }

  // -- 4) Coche abierto olvidado (aparcado y desbloqueado durante mas de X minutos) --
  final parked = (status.speed ?? 0) <= 0.5;
  if (!status.isLocked && parked) {
    unlockedSinceTs ??= DateTime.now().millisecondsSinceEpoch;
    final elapsedMin = (DateTime.now().millisecondsSinceEpoch - unlockedSinceTs) / 60000;
    if (elapsedMin >= _unlockedReminderMinutes && !unlockReminderSent) {
      await _showNotification(plugin, 1004, 'Coche abierto', 'Tu Leapmotor lleva mas de $_unlockedReminderMinutes min desbloqueado y aparcado.');
      unlockReminderSent = true;
    }
  } else {
    unlockedSinceTs = null;
    unlockReminderSent = false;
  }

  await _storage.write(key: _notifStateKey, value: json.encode({
    'soc': soc,
    'isLocked': status.isLocked,
    'chargeCompleted': status.chargeCompleted,
    'lowBatteryNotified': lowBatteryNotified,
    'unlockedSinceTs': unlockedSinceTs,
    'unlockReminderSent': unlockReminderSent,
  }));
}

/// Comparativa de eficiencia: consumo medio (% cada 100 km) de esta semana
/// frente a la semana anterior.
///
/// Antes recorria TripPointStore.load(), el almacen corto en memoria, y por eso
/// la tarjeta mostraba "--" pese a haber semanas enteras de datos: el historico
/// de verdad vive en trips.jsonl. Ahora se apoya en DailyStats.weeks(), que lee
/// el archivo permanente y esta validado contra los datos reales (diferencia
/// 0,000 %/100 km frente al calculo directo).
class WeeklyEfficiency {
  final double? thisWeek;
  final double? lastWeek;
  final double kmThis;
  final double kmLast;
  WeeklyEfficiency({this.thisWeek, this.lastWeek, this.kmThis = 0, this.kmLast = 0});
}

Future<WeeklyEfficiency> computeWeeklyEfficiency() async {
  try {
    final dias = await DailyStats.load();
    if (dias.isEmpty) return WeeklyEfficiency();
    final semanas = DailyStats.weeks(dias);
    if (semanas.isEmpty) return WeeklyEfficiency();

    final kNow = DailyStats.weekKey(DateTime.now());
    final kPrev = DailyStats.weekKey(DateTime.now().subtract(const Duration(days: 7)));

    DayAgg? buscar(String clave) {
      for (final w in semanas) {
        if (w.d == clave) return w;
      }
      return null;
    }

    final a = buscar(kNow);
    final b = buscar(kPrev);

    double? avg(DayAgg? w) {
      if (w == null || w.km < DailyStats.kMinKm) return null;
      final v = w.soc / w.km * 100.0;
      if (v < DailyStats.kMinAvg || v > DailyStats.kMaxAvg) return null;
      return v;
    }

    return WeeklyEfficiency(
      thisWeek: avg(a),
      lastWeek: avg(b),
      kmThis: a?.kmAll ?? 0,
      kmLast: b?.kmAll ?? 0,
    );
  } catch (_) {
    return WeeklyEfficiency();
  }
}

class WeeklyEfficiencyCard extends StatefulWidget {
  const WeeklyEfficiencyCard({super.key});

  @override
  State<WeeklyEfficiencyCard> createState() => _WeeklyEfficiencyCardState();
}

class _WeeklyEfficiencyCardState extends State<WeeklyEfficiencyCard> {
  WeeklyEfficiency _data = WeeklyEfficiency();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await computeWeeklyEfficiency();
    if (mounted) setState(() => _data = d);
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFBFE0FA);
    const textColor = Color(0xFF0D3B66);

    String fmt(double? v) => v == null ? '--' : AppLocalizations.of(context)!.percentPer100kmFmt(v.toStringAsFixed(1));

    String? comparisonText;
    if (_data.thisWeek != null && _data.lastWeek != null) {
      final diff = _data.thisWeek! - _data.lastWeek!;
      comparisonText = diff <= 0
          ? AppLocalizations.of(context)!.betterThisWeekMsg
          : AppLocalizations.of(context)!.worseThisWeekMsg;
    }

    return Container(
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.weeklyEfficiencyTitle, style: const TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 15)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(AppLocalizations.of(context)!.thisWeekLabel, style: const TextStyle(color: textColor, fontSize: 11)),
                Text(fmt(_data.thisWeek), style: const TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
              ]),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(AppLocalizations.of(context)!.lastWeekLabel, style: const TextStyle(color: textColor, fontSize: 11)),
                Text(fmt(_data.lastWeek), style: const TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
              ]),
            ],
          ),
          if (comparisonText != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(comparisonText, style: const TextStyle(color: textColor, fontSize: 12, fontStyle: FontStyle.italic)),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(AppLocalizations.of(context)!.needBothWeeksMsg, style: const TextStyle(color: textColor, fontSize: 11)),
            ),
        ],
      ),
    );
  }
}


Future<void> exportAnonymizedJson(BuildContext context, Vehicle vehicle) async {
  final chargeSessions = await ChargeHistoryStore.load();
  final tripPoints = await TripPointStore.load();
  final batteryHistory = await BatteryHistoryStore.load();
  final efficiency = await computeWeeklyEfficiency();

  final export = {
    'exportedAt': DateTime.now().toIso8601String(),
    'vehicleModel': vehicle.carType,
    'batteryHistory': batteryHistory,
    'chargeSessions': chargeSessions.map((s) => s.toMap()).toList(),
    'consumptionAvgPercentPer100km': TripPointStore.averageConsumptionPercentPer100km(tripPoints),
    'weeklyEfficiency': {'thisWeek': efficiency.thisWeek, 'lastWeek': efficiency.lastWeek},
    'note': 'Datos anonimizados: sin VIN, matricula, ubicacion GPS, nombre de usuario ni identificadores unicos del vehiculo.',
  };

  const encoder = JsonEncoder.withIndent('  ');
  final jsonStr = encoder.convert(export);

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/lmb10_export_${DateTime.now().millisecondsSinceEpoch}.json');
  await file.writeAsString(jsonStr);

  await Share.shareXFiles([XFile(file.path)], text: 'Exportacion anonimizada de datos LMB10');
}

/// Accion pedida desde el widget de acciones rapidas: lmb10://action?cmd=lock
String? _actionFromUri(Uri? uri) {
  if (uri == null) return null;
  if (uri.host != 'action') return null;
  final cmd = uri.queryParameters['cmd'];
  return (cmd == null || cmd.isEmpty) ? null : cmd;
}

/// Callback de FONDO del widget: se ejecuta sin abrir la app, asi que funciona
/// con el movil bloqueado. Solo llega aqui lo que se dispara con
/// HomeWidgetBackgroundIntent (cerrar, clima). Abrir y maletero van por
/// HomeWidgetLaunchIntent a proposito, para que Android exija desbloqueo.
@pragma('vm:entry-point')
Future<void> widgetActionCallback(Uri? uri) async {
  final cmd = _actionFromUri(uri);
  if (cmd == null) return;
  await CarLogBridge.log('VIA-FONDO ' + cmd);
  // El comando tarda: hay que verificar el PIN contra el servidor y luego
  // esperar al resultado. Sin aviso, el widget parece roto.
  Future<void> aviso(String t) async {
    try {
      await HomeWidget.saveWidgetData<String>('qw_status', t);
      await HomeWidget.updateWidget(androidName: 'QuickWidgetProvider');
    } catch (_) {}
  }
  await aviso('enviando...');
  final ok = await carQuickAction(cmd);
  await CarLogBridge.log('widget accion fondo ' + cmd + ' -> ' + ok.toString() +
      (ok ? '' : ' (' + gQuickActionError + ')'));
  await aviso(ok
      ? 'hecho'
      : (gQuickActionError.isEmpty ? 'Error' : gQuickActionError));
  // Los fallos se dejan mas tiempo: "Sin cobertura" hay que poder leerlo.
  await Future.delayed(Duration(seconds: ok ? 5 : 12));
  await aviso('');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadVehicleProfile();
  await _initNotifications();
  Workmanager().initialize(backgroundCallbackDispatcher, isInDebugMode: false);
  Workmanager().registerPeriodicTask(
    'lm_refresh_task',
    'lmRefreshVehicleData',
    frequency: const Duration(minutes: 15), // minimo permitido por Android
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );
  try {
    gPendingRoutineId = _routineIdFromUri(await HomeWidget.initiallyLaunchedFromHomeWidget());
  } catch (_) {}
  try {
    HomeWidget.registerInteractivityCallback(widgetActionCallback);
  } catch (_) {}
  try {
    final cmd0 = _actionFromUri(await HomeWidget.initiallyLaunchedFromHomeWidget());
    if (cmd0 != null) {
      await CarLogBridge.log('VIA-ARRANQUE ' + cmd0);
      // La Activity solo arranca tras desbloquear, asi que esto se ejecuta ya
      // con el usuario autenticado.
      unawaited(carQuickAction(cmd0));
    }
  } catch (_) {}
  HomeWidget.widgetClicked.listen((uri) {
    final id = _routineIdFromUri(uri);
    if (id != null) {
      gPendingRoutineId = id;
      gOnRoutinePending?.call();
    }
    final cmd = _actionFromUri(uri);
    if (cmd != null) {
      unawaited(CarLogBridge.log('VIA-CLIC ' + cmd));
      unawaited(carQuickAction(cmd));
    }
  });
  runApp(const LPB10App());
}

class LPB10App extends StatelessWidget {
  const LPB10App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LMB10',
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Colors.black),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SplashScreen(),
    );
  }
}

// ============================================================
// Splash: intenta restaurar sesion guardada antes de pedir login
// ============================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _tryRestore();
  }

  Future<void> _tryRestore() async {
    if (!await welcomeAccepted()) {
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => WelcomeScreen(
              onAccept: () => Navigator.of(context).pop())));
    }
    if (!await hasClientCert()) {
      if (!mounted) return;
      await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CertImportScreen()));
      if (!mounted) return;
      if (!await hasClientCert()) { _goToLogin(); return; }
    }
    try {
      final raw = await _storage.read(key: _sessionKey);
      if (raw == null) {
        _goToLogin();
        return;
      }
      final sessionMap = Map<String, String>.from(json.decode(raw) as Map);
      final session = SessionData.fromMap(sessionMap);

      final staticClient = await createStaticClient();
      final client = LeapmotorApiClient(staticClient);
      await client.restoreSession(session);

      final vehicles = await client.getVehicleList();
      if (vehicles.isEmpty) throw Exception('Sin vehiculos');

      final savedVin = await _storage.read(key: _vinKey);
      final vehicle = vehicles.firstWhere((v) => v.vin == savedVin, orElse: () => vehicles.first);
      final pin = await _storage.read(key: _pinKey) ?? '';

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => DashboardScreen(client: client, vehicle: vehicle, pin: pin)),
      );
    } catch (_) {
      await _storage.delete(key: _sessionKey);
      _goToLogin();
    }
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

// ============================================================
// Login
// ============================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  bool _loading = false;
  bool _rememberPin = false;
  String? _error;

  Future<void> _doLogin() async {
    final esLoc = Localizations.localeOf(context).languageCode == 'es';
    setState(() { _loading = true; _error = null; });
    try {
      if (!await hasClientCert()) {
        throw Exception(esLoc
            ? 'Falta el certificado de cliente. Ve a Ajustes > Certificado.'
            : 'Client certificate missing. Go to Settings > Certificate.');
      }
      final staticClient = await createStaticClient();
      final client = LeapmotorApiClient(staticClient);
      await client.login(_emailCtrl.text.trim(), _passCtrl.text.trim());
      final vehicles = await client.getVehicleList();
      if (vehicles.isEmpty) throw Exception('No se encontro ningun vehiculo asociado a la cuenta.');

      final session = client.exportSession();
      await _storage.write(key: _sessionKey, value: json.encode(session.toMap()));
      await _storage.write(key: _vinKey, value: vehicles.first.vin);
      if (_rememberPin && _pinCtrl.text.trim().isNotEmpty) {
        await _storage.write(key: _pinKey, value: _pinCtrl.text.trim());
      } else {
        await _storage.delete(key: _pinKey);
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DashboardScreen(client: client, vehicle: vehicles.first, pin: _pinCtrl.text.trim()),
        ),
      );
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.loginScreenTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(controller: _emailCtrl, decoration: InputDecoration(labelText: AppLocalizations.of(context)!.emailLabel)),
            const SizedBox(height: 16),
            TextField(controller: _passCtrl, obscureText: true, decoration: InputDecoration(labelText: AppLocalizations.of(context)!.passwordLabel)),
            const SizedBox(height: 16),
            TextField(
              controller: _pinCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.pinLabel,
                helperText: AppLocalizations.of(context)!.pinHelper,
              ),
            ),
            CheckboxListTile(
              value: _rememberPin,
              onChanged: (v) => setState(() => _rememberPin = v ?? false),
              title: Text(AppLocalizations.of(context)!.rememberPinTitle),
              subtitle: Text(AppLocalizations.of(context)!.rememberPinSubtitle),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 8),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(onPressed: _doLogin, child: Text(AppLocalizations.of(context)!.loginButton)),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Dashboard
// ============================================================
class DashboardScreen extends StatefulWidget {
  final LeapmotorApiClient client;
  final Vehicle vehicle;
  final String pin;
  const DashboardScreen({super.key, required this.client, required this.vehicle, required this.pin});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  VehicleStatus? _status;
  String? _transientError;
  bool _refreshing = false;
  int _unreadMsgs = 0;
  DateTime? _lastFetched;
  Timer? _autoRefreshTimer;
  Timer? _tickTimer;
  late String _sessionPin;
  bool _showMap = true;

  @override
  void initState() {
    super.initState();
    _sessionPin = widget.pin;
    gOnRoutinePending = () { if (mounted) _maybeRunPendingRoutine(); };
    loadShowMapSetting().then((v) { if (mounted) setState(() => _showMap = v); });
    _loadStatus();
    _refreshUnread();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 90), (_) => _loadStatus());
    _tickTimer = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _tickTimer?.cancel();
    super.dispose();
  }

  bool _isTransientNetworkError(Object e) =>
      e is SocketException || e.toString().toLowerCase().contains('socketexception') || e.toString().toLowerCase().contains('failed host lookup');

  VehicleStatus? _previousStatus;

  Future<void> _updateChargeAndTripHistory(VehicleStatus s) async {
    final soc = s.preciseSoc ?? s.soc?.toDouble();
    if (soc == null) return;

    // Rescata cualquier sesion huerfana antes de la deteccion normal.
    await ChargeHistoryStore.reconcileOpenSession(
      isPluggedIn: s.isPluggedIn,
      chargeCompleted: s.chargeCompleted == true,
      currentSoc: soc,
    );
    final wasCharging = _previousStatus?.isCharging ?? false;
    if (!wasCharging && s.isCharging) {
      await ChargeHistoryStore.startSession(soc);
    } else if (wasCharging && !s.isCharging) {
      await ChargeHistoryStore.endSession(soc);
    }

    if (s.totalMileage != null && !s.isCharging) {
      await TripPointStore.addPoint(s.totalMileage!, soc);
    }
    _previousStatus = s;
  }

  Future<void> _maybeRunPendingRoutine() async {
    final id = gPendingRoutineId;
    if (id == null) return;
    gPendingRoutineId = null;
    final pin = await _resolvePin();
    if (pin == null || pin.isEmpty) return;
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RoutinesScreen(
        client: widget.client,
        vin: widget.vehicle.vin,
        pin: pin,
        status: _status,
        autoRunId: id,
      ),
    ));
    _loadStatus();
  }

  Future<void> _refreshUnread() async {
    try {
      final n = await widget.client.getUnreadMessageCount();
      final seen = int.tryParse(await _storage.read(key: 'lm_msgs_seen_v1') ?? '0') ?? 0;
      final pending = (n - seen) < 0 ? 0 : (n - seen);
      if (mounted) setState(() => _unreadMsgs = pending);
    } catch (_) {}
  }

  Future<void> _markMessagesSeen() async {
    try {
      final n = await widget.client.getUnreadMessageCount();
      await _storage.write(key: 'lm_msgs_seen_v1', value: '$n');
      if (mounted) setState(() => _unreadMsgs = 0);
    } catch (_) {}
  }

  Future<void> _loadStatus({bool retryOnTransient = true}) async {
    setState(() { _refreshing = true; _transientError = null; });
    try {
      final status = await widget.client.getVehicleStatus(widget.vehicle.vin);
      setState(() { _status = status; _refreshing = false; _lastFetched = DateTime.now(); _transientError = null; });
      _refreshUnread();
      _maybeRunPendingRoutine();
      await _pushToHomeWidget(status);
      await _updateChargeAndTripHistory(status);
      await checkAndNotifyStateChanges(status);
    } catch (e) {
      if (_isTransientNetworkError(e) && retryOnTransient) {
        // Fallo de red puntual (sin datos, tunel, etc.) -> reintenta una vez tras 3s
        await Future.delayed(const Duration(seconds: 3));
        if (!mounted) return;
        await _loadStatus(retryOnTransient: false);
        return;
      }
      // Mantiene el ultimo estado conocido visible; solo muestra un aviso discreto
      setState(() {
        _refreshing = false;
        _transientError = _isTransientNetworkError(e)
            ? 'Sin conexion con el servidor (reintentando en segundo plano)'
            : e.toString();
      });
    }
  }

  String get _lastUpdatedLabel {
    if (_lastFetched == null) return '';
    final diff = DateTime.now().difference(_lastFetched!);
    if (diff.inSeconds < 60) return AppLocalizations.of(context)!.lastUpdatedSeconds(diff.inSeconds);
    return AppLocalizations.of(context)!.lastUpdatedMinutes(diff.inMinutes);
  }

  String _chargeStateLabel(VehicleStatus s, AppLocalizations t) {
    if (s.isCharging) return t.chargingLabel;
    if (s.isPluggedIn) return t.notChargingLabel;
    return t.disconnectedLabel;
  }

  Future<String?> _resolvePin() async {
    if (_sessionPin.isNotEmpty) return _sessionPin;
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.pinDialogTitle),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'PIN'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context)!.pinDialogCancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: Text(AppLocalizations.of(context)!.pinDialogAccept)),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() => _sessionPin = result);
    }
    return result;
  }

  Future<void> _logout() async {
    await _storage.delete(key: _sessionKey);
    await _storage.delete(key: _pinKey);
    await _storage.delete(key: _vinKey);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.vehicle.nickName ?? AppLocalizations.of(context)!.dashboardDefaultTitle),
        actions: [
          IconButton(
            icon: _refreshing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            onPressed: _refreshing ? null : () => _loadStatus(),
            tooltip: AppLocalizations.of(context)!.refreshTooltip,
          ),
          IconButton(
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
            tooltip: Localizations.localeOf(context).languageCode == 'es' ? 'Mensajes' : 'Messages',
            icon: Badge(
              isLabelVisible: _unreadMsgs > 0,
              label: Text(_unreadMsgs > 9 ? '9+' : '$_unreadMsgs'),
              child: const Icon(Icons.mail_outline),
            ),
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => MessagesScreen(client: widget.client)));
              await _markMessagesSeen();
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings_outlined),
            tooltip: AppLocalizations.of(context)!.settingsTooltip,
            onSelected: (v) async {
              final es = Localizations.localeOf(context).languageCode == 'es';
              switch (v) {
                case 'settings':
                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
                  final s = await loadShowMapSetting();
                  if (mounted) setState(() => _showMap = s);
                  break;
                case 'guard':
                  final pin = await _resolvePin();
                  if (pin == null || pin.isEmpty) return;
                  if (!mounted) return;
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => GuardModeScreen(client: widget.client, vehicle: widget.vehicle, pin: pin)),
                  );
                  _loadStatus();
                  break;
                case 'debug':
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => DebugStatusScreen(client: widget.client, vehicle: widget.vehicle)),
                  );
                  break;
              }
            },
            itemBuilder: (context) {
              final es = Localizations.localeOf(context).languageCode == 'es';
              return [
                PopupMenuItem(value: 'settings', child: ListTile(dense: true, leading: const Icon(Icons.tune), title: Text(AppLocalizations.of(context)!.settingsTooltip))),
                const PopupMenuDivider(),
                PopupMenuItem(value: 'guard', child: ListTile(dense: true, leading: const Icon(Icons.shield_outlined), title: Text(AppLocalizations.of(context)!.guardModeButton))),
                PopupMenuItem(value: 'debug', child: ListTile(dense: true, leading: const Icon(Icons.bug_report_outlined), title: Text(AppLocalizations.of(context)!.debugButton))),
              ];
            },
          ),
          IconButton(
            icon: const Icon(Icons.eco_outlined),
            tooltip: Localizations.localeOf(context).languageCode == 'es' ? 'Coach de eficiencia' : 'Efficiency coach',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => EfficiencyCoachScreen(status: _status),
            )),
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: Localizations.localeOf(context).languageCode == 'es' ? 'Ticket de eficiencia' : 'Efficiency ticket',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const TicketScreen(),
            )),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: AppLocalizations.of(context)!.aboutTooltip,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutScreen())),
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout, tooltip: AppLocalizations.of(context)!.logoutTooltip),
        ],
      ),
      body: s == null
          ? (_transientError != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_transientError!, style: const TextStyle(color: Colors.red))))
              : const Center(child: CircularProgressIndicator()))
          : RefreshIndicator(
              onRefresh: () => _loadStatus(),
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (_transientError != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                      child: Text(_transientError!, style: const TextStyle(color: Colors.amber, fontSize: 12)),
                    ),
(_showMap && s.latitude != null && s.longitude != null)
                      ? LocationCard(latitude: s.latitude!, longitude: s.longitude!)
                      : (_showMap ? const SizedBox(height: 60, child: Center(child: Text('Sin datos de ubicacion'))) : const SizedBox.shrink()),
                  if (_showMap) const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(_lastUpdatedLabel, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ),
                  const SizedBox(height: 6),
                  _buildTileGrid(s),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.settings),
                    label: Text(AppLocalizations.of(context)!.controlsButton),
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: () async {
                      final pin = await _resolvePin();
                      if (pin == null || pin.isEmpty) return;
                      if (!mounted) return;
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ControlsScreen(client: widget.client, vehicle: widget.vehicle, pin: pin),
                        ),
                      );
                      _loadStatus();
                    },
                  ),
                      const SizedBox(height: 12),
                      BatteryWidgetCard(
                        currentSoc: s.preciseSoc ?? s.soc?.toDouble(),
                        remainingRange: s.liveRemainingRange,
                        isLocked: s.isLocked,
                        lastUpdated: _lastFetched,
                      ),
                      const SizedBox(height: 12),
                      ConsumptionCard(reportedRange: s.liveRemainingRange, currentSoc: s.preciseSoc ?? s.soc?.toDouble()),
                      const SizedBox(height: 12),
                      const EnergyCostCard(),

                      const ChargeHistoryCard(),
                      const SizedBox(height: 12),
                      const WeeklyEfficiencyCard(),
                      const SizedBox(height: 12),
                      PowerCard(status: s),
                      const SizedBox(height: 12),
                      TirePressureCard(status: s),
                      const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.security, size: 18),
                    label: Text(Localizations.localeOf(context).languageCode == 'es' ? 'Modo Centinela' : 'Sentry Mode'),
                    onPressed: () async {
                      final pin = await _resolvePin();
                      if (pin == null || pin.isEmpty) return;
                      if (!mounted) return;
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SentryScreen(vin: widget.vehicle.vin, pin: pin),
                        ),
                      );
                      _loadStatus();
                    },
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.ac_unit, size: 18),
                    label: Text(AppLocalizations.of(context)!.preconditioningButton),
                    onPressed: () async {
                      final pin = await _resolvePin();
                      if (pin == null || pin.isEmpty) return;
                      if (!mounted) return;
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PreconditioningScreen(client: widget.client, vehicle: widget.vehicle, pin: pin),
                        ),
                      );
                      _loadStatus();
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMap(VehicleStatus s) {
    if (s.latitude == null || s.longitude == null) {
      return const SizedBox(height: 90, child: Center(child: Text('Sin datos de ubicacion')));
    }
    final point = LatLng(s.latitude!, s.longitude!);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => FullMapScreen(latitude: s.latitude!, longitude: s.longitude!)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 140,
          child: Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: point,
                  initialZoom: 14.0,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.txurtxil.lpb10',
                  ),
                  MarkerLayer(markers: [
                    Marker(point: point, width: 34, height: 34, child: const Icon(Icons.directions_car, color: Colors.deepPurple, size: 26)),
                  ]),
                ],
              ),
              Positioned(
                right: 6, top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.open_in_full, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTileGrid(VehicleStatus s) {
    final soc = s.preciseSoc?.toStringAsFixed(1) ?? s.soc?.toString() ?? '--';
    final t = AppLocalizations.of(context)!;
    final tiles = <_TileData>[
      _TileData(Icons.battery_full, '$soc%', t.tileBattery),
      _TileData(Icons.social_distance, '${s.liveRemainingRange ?? '--'} km', t.tileAutonomy),
      _TileData(s.isLocked ? Icons.lock : Icons.lock_open, s.isLocked ? t.lockedLabel : t.unlockedLabel, t.tileLock),
      _TileData(Icons.ev_station, _chargeStateLabel(s, t), t.tileChargeState),
      _TileData(s.isPluggedIn ? Icons.power : Icons.power_off, s.isPluggedIn ? t.connectedLabel : t.disconnectedShortLabel, t.tileChargeCable),
      _TileData(Icons.thermostat, s.batteryThermalRequest == 1 ? t.activeLabel : t.normalLabel, t.tileThermalMgmt),
      _TileData(s.acSwitch == true ? Icons.ac_unit : Icons.ac_unit_outlined, s.acSwitch == true ? t.onLabel : t.offLabel, t.tileClimate),
      _TileData(s.bbcmBackDoorStatus == true ? Icons.inventory_2 : Icons.inventory_2_outlined, s.bbcmBackDoorStatus == true ? t.openLabel : t.closedLabel, t.tileTrunk),
      _TileData(Icons.security, s.sentryMode == 1 ? t.activeShortLabel : t.inactiveLabel, t.tileSentry),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.95,
      children: tiles.map((t) => _StatTile(data: t)).toList(),
    );
  }
}


class BatteryHistoryStore {
  static const _key = 'lm_battery_history_v1';
  static const _maxPoints = 40;

  static Future<List<Map<String, dynamic>>> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return [];
    try {
      return List<Map<String, dynamic>>.from(
        (json.decode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)),
      );
    } catch (_) {
      return [];
    }
  }

  static Future<void> addPoint(double soc) async {
    final points = await load();
    points.add({'ts': DateTime.now().millisecondsSinceEpoch, 'soc': soc});
    final trimmed = points.length > _maxPoints ? points.sublist(points.length - _maxPoints) : points;
    await _storage.write(key: _key, value: json.encode(trimmed));
  }
}

/// Tarjeta tipo "widget": historial de bateria en barras + accesos rapidos,
/// pensada para vivir dentro del dashboard con fondo azul claro.
class BatteryWidgetCard extends StatefulWidget {
  final double? currentSoc;
  final int? remainingRange;
  final bool isLocked;
  final DateTime? lastUpdated;
  const BatteryWidgetCard({
    super.key, required this.currentSoc, required this.remainingRange, required this.isLocked, required this.lastUpdated,
  });

  @override
  State<BatteryWidgetCard> createState() => _BatteryWidgetCardState();
}


class _BatteryWidgetCardState extends State<BatteryWidgetCard> {
  List<Map<String, dynamic>> _history = [];
  bool _showHelp = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void didUpdateWidget(covariant BatteryWidgetCard old) {
    super.didUpdateWidget(old);
    if (old.currentSoc != widget.currentSoc && widget.currentSoc != null) {
      BatteryHistoryStore.addPoint(widget.currentSoc!).then((_) => _loadHistory());
    }
  }

  Future<void> _loadHistory() async {
    final h = await BatteryHistoryStore.load();
    if (mounted) setState(() => _history = h);
  }

  String get _lastUpdatedLabel {
    if (widget.lastUpdated == null) return '';
    final diff = DateTime.now().difference(widget.lastUpdated!);
    if (diff.inSeconds < 60) return AppLocalizations.of(context)!.lastUpdatedSecondsShort(diff.inSeconds);
    return AppLocalizations.of(context)!.lastUpdatedMinutesShort(diff.inMinutes);
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFBFE0FA);
    const barColor = Color(0xFF1565C0);
    const textColor = Color(0xFF0D3B66);
    final soc = widget.currentSoc?.toStringAsFixed(1) ?? '--';

    return Container(
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppLocalizations.of(context)!.tileBattery, style: const TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 15)),
              Text(_lastUpdatedLabel, style: const TextStyle(color: textColor, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$soc%', style: const TextStyle(color: textColor, fontSize: 30, fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(AppLocalizations.of(context)!.rangeKmAutonomy('${widget.remainingRange ?? '--'}'), style: const TextStyle(color: textColor, fontSize: 13)),
              ),
              const Spacer(),
              Icon(widget.isLocked ? Icons.lock : Icons.lock_open, color: textColor, size: 20),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 70,
            child: _history.isEmpty
                ? const Center(child: Text('Historial vacio (se rellena con el uso)', style: TextStyle(color: textColor, fontSize: 11)))
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: _history.map((p) {
                      final v = (p['soc'] as num).toDouble().clamp(0, 100);
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: Container(
                            height: 62 * (v / 100),
                            decoration: BoxDecoration(
                              color: barColor.withOpacity(0.55 + 0.45 * (v / 100)),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => setState(() => _showHelp = !_showHelp),
            child: Row(
              children: [
                Icon(_showHelp ? Icons.expand_less : Icons.help_outline,
                    size: 16, color: textColor),
                const SizedBox(width: 4),
                Text(
                  Localizations.localeOf(context).languageCode == 'es'
                      ? 'Que significa esto?'
                      : 'What does this mean?',
                  style: const TextStyle(
                      color: textColor, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (_showHelp)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                Localizations.localeOf(context).languageCode == 'es'
                    ? 'Barras: cada barra es una lectura del nivel de bateria guardada por la app. La mas antigua a la izquierda, la mas reciente a la derecha. Bajan cuando conduces y suben cuando cargas; sirven para ver la evolucion de un vistazo. No son consumo: para eso esta la tarjeta Consumo y autonomia real.\n\nPorcentaje grande: carga actual con un decimal, mas preciso que el numero redondeado del coche.\n\nKm: autonomia que reporta el coche en esta lectura.\n\nCandado: si el coche estaba cerrado o abierto en la ultima lectura.\n\nHace X: cuando se tomaron estos datos. La app consulta cada 90 s con la app abierta y cada 15 min en segundo plano (limite de Android), asi que no es informacion en vivo.'
                    : 'Bars: each bar is a battery level reading stored by the app. Oldest on the left, most recent on the right. They go down as you drive and up as you charge, so you can see the trend at a glance. They are not consumption: see the Real consumption and range card for that.\n\nBig percentage: current charge with one decimal, more precise than the rounded figure shown by the car.\n\nKm: range reported by the car in this reading.\n\nPadlock: whether the car was locked or unlocked at the last reading.\n\nX ago: when this data was read. The app polls every 90 s while open and every 15 min in the background (Android limit), so it is not live data.',
                style: const TextStyle(color: textColor, fontSize: 11, height: 1.35),
              ),
            ),
        ],
      ),
    );
  }
}



/// Replica de _readPermanentTrips (widget_chart) para uso en main.dart.
Future<List<({int ts, int km, double soc})>> _readPermanentTripsMain() async {
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

Future<void> _pushToHomeWidget(VehicleStatus s) async {
  final soc = (s.preciseSoc ?? s.soc?.toDouble())?.toStringAsFixed(1);
  await HomeWidget.saveWidgetData<String>('soc', soc ?? '--');
  await HomeWidget.saveWidgetData<String>('range', '${s.liveRemainingRange ?? '--'}');
  // Odometro para el widget y el mantenimiento. No viajaba hasta ahora.
  await HomeWidget.saveWidgetData<String>(
      'odometro', s.totalMileage?.toString() ?? '');
  // Aviso de mantenimiento: solo habla cuando queda poco. Un aviso permanente
  // se deja de mirar.
  try {
    await HomeWidget.saveWidgetData<String>(
        'mant_aviso', await Mantenimiento.aviso(s.totalMileage ?? 0));
  } catch (_) {}
  await HomeWidget.saveWidgetData<String>('locked', s.isLocked ? '1' : '0');
  await HomeWidget.saveWidgetData<String>('updated', 'Actualizado ${TimeOfDay.now().format24Hour()}');
  // Marca de tiempo cruda para poder decir "hace N min". Con el TCU
  // durmiendose a los ~13 min, la hora exacta parece fresca aunque el dato
  // tenga horas; la antiguedad es la informacion mas honesta del widget.
  await HomeWidget.saveWidgetData<String>(
      'updatedTs', DateTime.now().millisecondsSinceEpoch.toString());
  await HomeWidget.saveWidgetData<String>('lat', s.latitude != null ? s.latitude.toString() : '');
  await HomeWidget.saveWidgetData<String>('lon', s.longitude != null ? s.longitude.toString() : '');
  // Direccion legible para el widget. La cache persistida evita llamar a
  // Nominatim en cada refresco: solo sale peticion si el coche se ha movido
  // mas de 300 m desde la ultima resuelta.
  if (s.latitude != null && s.longitude != null) {
    try {
      final dir = await _AddressCache.resolve(s.latitude!, s.longitude!);
      await HomeWidget.saveWidgetData<String>('carAddress', dir);
    } catch (_) {}
  }
  // --- Android Auto: datos extra para sub-pantallas Bateria/Ruedas ---
  await HomeWidget.saveWidgetData<String>('volt', s.raw['batteryVoltage']?.toString() ?? '');
  await HomeWidget.saveWidgetData<String>('amp', s.raw['batteryCurrent']?.toString() ?? '');
  await HomeWidget.saveWidgetData<String>('kw', s.batteryPowerKw?.toStringAsFixed(2) ?? '');
  await HomeWidget.saveWidgetData<String>('interiorTemp', s.raw['interiorTemp']?.toString() ?? '');
  // Temp. bateria: el coche NO la reporta siempre (TCU dormido / sin cargar).
  // Si falta, NO se machaca el ultimo valor bueno; se conserva y se guarda la
  // marca de tiempo para que Android Auto muestre la antiguedad del dato.
  final btRaw = s.raw['minBatteryTemp'];
  if (btRaw != null && btRaw.toString().trim().isNotEmpty) {
    await HomeWidget.saveWidgetData<String>('batteryTemp', btRaw.toString());
    await HomeWidget.saveWidgetData<String>(
        'batteryTempTs', DateTime.now().millisecondsSinceEpoch.toString());
  }
  await HomeWidget.saveWidgetData<String>('chargeRemainTime', s.raw['chargeRemainTime']?.toString() ?? '');
  await HomeWidget.saveWidgetData<String>('tireAlerts', s.tirePressureAlerts.join('|'));
  // Presiones en kPa para la silueta de Android Auto. Hasta ahora solo viajaba
  // tireAlerts (nombres de ruedas en alerta), asi que la pantalla del coche no
  // tenia los numeros y pintaba una barra que en realidad no media nada.
  // Orden fijo: delantera izq, delantera der, trasera izq, trasera der.
  // Vacio = sin lectura; NO se manda 0, que se confundiria con una presion.
  await HomeWidget.saveWidgetData<String>(
      'tireKpa',
      [s.leftFrontTireKpa, s.rightFrontTireKpa, s.leftRearTireKpa, s.rightRearTireKpa]
          .map((v) => v?.toString() ?? '')
          .join('|'));
  await HomeWidget.saveWidgetData<String>(
      'tireState',
      ['leftFrontTirePressureState', 'rightFrontTirePressureState',
       'leftRearTirePressureState', 'rightRearTirePressureState']
          .map((k) => s.raw[k]?.toString() ?? '')
          .join('|'));
  // Lista completa de rutinas para la rejilla del coche (id::nombre por linea)
  try {
    final all = await RoutineStore.load();
    final enc = all.map((r) => r.id + '::' + r.name).join('\n');
    await HomeWidget.saveWidgetData<String>('routines_all', enc);
  } catch (_) {}
  // --- Android Auto: idioma (headless, sin BuildContext) ---
  final _isEs = Platform.localeName.toLowerCase().startsWith('es');
  await HomeWidget.saveWidgetData<String>('lang', _isEs ? 'es' : 'en');
  // --- Android Auto: consumo del CICLO actual (desde ultima recarga) ---
  try {
    var pts = await _readPermanentTripsMain();
    if (pts.length >= 2) {
      // Inicio del ciclo: MISMA logica que el widget (widget_chart.dart),
      // que ya da los km de ciclo correctos. Ultimo salto de SoC >=3 entre
      // puntos consecutivos = ultima recarga. No reinventar: una sola verdad.
      int rechargeIdx = 0;
      for (var i = 1; i < pts.length; i++) {
        if (pts[i].soc - pts[i - 1].soc >= 3) rechargeIdx = i - 1;
      }
      final cyclePts = pts.sublist(rechargeIdx);
      final tp = cyclePts
          .map((e) => TripPoint(ts: e.ts, totalMileage: e.km, soc: e.soc))
          .toList();
      final avgPct = TripPointStore.averageConsumptionPercentPer100km(tp);
      // km del ciclo (odometro actual - odometro al recargar)
      final cycleKmDriven = cyclePts.isNotEmpty
          ? (cyclePts.last.km - cyclePts.first.km)
          : 0;
      await HomeWidget.saveWidgetData<String>('cycle_km', cycleKmDriven.toString());
      // Barras por dia (solo si el ciclo abarca >1 dia).
      // Se descartan puntos con timestamp futuro (imposibles: datos corruptos
      // que hacian aparecer fechas que aun no han llegado, p.ej. agosto en julio).
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      // Las barras por dia NO pueden depender del ciclo: cada recarga mueve
      // rechargeIdx al final, cyclePts se queda en 2-3 puntos y el historico
      // por dias desaparece (solo se veia el dia en curso). Se recorre TODO
      // el historico permanente y luego se limita a los 7 ultimos dias.
      final allTp = pts
          .map((e) => TripPoint(ts: e.ts, totalMileage: e.km, soc: e.soc))
          .toList();
      final byDay = <String, List<TripPoint>>{};
      for (final p in allTp) {
        // TripPoint.ts YA viene en milisegundos. Multiplicarlo por 1000
        // daba fechas del año 58525 y el filtro de futuro descartaba todos
        // los puntos: por eso no salia ningun dia. Se autodetecta la unidad
        // por si quedan puntos antiguos guardados en segundos.
        final ms = p.ts > 100000000000 ? p.ts : p.ts * 1000;
        if (ms > nowMs) continue; // punto en el futuro: dato invalido
        final dt = DateTime.fromMillisecondsSinceEpoch(ms);
        final key = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
        (byDay[key] ??= []).add(p);
      }
      // Antes solo se generaban barras si el ciclo abarcaba mas de un dia.
      // Con carga diaria el ciclo dura 1 dia y NUNCA salian barras. Ahora se
      // publican todos los dias con datos (maximo los 7 ultimos).
      final dayParts = <String>[];
      for (final entry in byDay.entries) {
        final a = TripPointStore.averageConsumptionPercentPer100km(entry.value);
        final kwh = a == null ? '' : (a / 100.0 * gBatteryKwh).toStringAsFixed(1);
        dayParts.add('${entry.key}:$kwh');
      }
      if (dayParts.length > 7) {
        dayParts.removeRange(0, dayParts.length - 7);
      }
      // Media de los 7 ultimos dias, independiente del ciclo. Justo despues
      // de recargar el ciclo no tiene datos y el resumen sale vacio; esta
      // cifra sigue siendo util. Los tramos de carga los descarta el filtro
      // de plausibilidad de averageConsumptionPercentPer100km.
      final recent7 = <TripPoint>[];
      final keys7 = byDay.keys.toList();
      final from7 = keys7.length > 7 ? keys7.length - 7 : 0;
      for (var i = from7; i < keys7.length; i++) {
        recent7.addAll(byDay[keys7[i]]!);
      }
      recent7.sort((a, b) => a.ts.compareTo(b.ts));
      final avg7 = TripPointStore.averageConsumptionPercentPer100km(recent7);
      await HomeWidget.saveWidgetData<String>(
          'avg7_kwh100',
          avg7 == null ? '' : (avg7 / 100.0 * gBatteryKwh).toStringAsFixed(1));
      // Motor de agregado diario (daily_stats.dart). Todavia NO alimenta la
      // interfaz: solo se sincroniza y deja una linea en el log para poder
      // comprobar que su avg7 coincide con el de arriba.
      try {
        await DailyStats.sync();
        await CarLogBridge.log('AGG ' + await DailyStats.diagnostic());
      } catch (e) {
        await CarLogBridge.log('AGG error ' + e.toString());
      }
      await CarLogBridge.log('CONSUMO avg7=' + (avg7 == null ? 'null' : avg7.toStringAsFixed(2)) +
          ' dias7=' + keys7.length.toString() + ' pts7=' + recent7.length.toString());
      // Diagnostico: deja en el log del coche por que salen o no los dias.
      if (tp.isNotEmpty) {
        final ultimoMs =
            tp.last.ts > 100000000000 ? tp.last.ts : tp.last.ts * 1000;
        final ultima = DateTime.fromMillisecondsSinceEpoch(ultimoMs);
        await CarLogBridge.log(
            'CONSUMO puntos=${tp.length} ultimoTs=${tp.last.ts} fecha=${ultima.toIso8601String()}');
      }
      await CarLogBridge.log(
          'CONSUMO dias=${byDay.keys.join("|")} parts=${dayParts.join("|")}');
      // Tercer campo de cada dia: los euros. Se toman del agregado diario,
      // que tiene los kWh REALES de la jornada. Calcularlo desde el kWh/100
      // seria un error: esa cifra ya viene dividida por kilometros.
      try {
        final precioDia = await EnergyPrice.load();
        final agg = await DailyStats.load();
        final eurDia = <String, String>{};
        final kmDia = <String, String>{};
        for (final ag in agg) {
          final iso = ag.d.split('-');
          if (iso.length != 3) continue;
          final k = iso[2] + '/' + iso[1];
          kmDia[k] = ag.kmAll.toStringAsFixed(0);
          if (precioDia != null) {
            eurDia[k] = (ag.soc / 100.0 * gBatteryKwh * precioDia.eurKwh)
                .toStringAsFixed(2);
          }
        }
        // Formato final de cada dia: "dd/MM:kwh100:euros:km".
        for (var i = 0; i < dayParts.length; i++) {
          final k = dayParts[i].split(':').first;
          dayParts[i] =
              dayParts[i] + ':' + (eurDia[k] ?? '') + ':' + (kmDia[k] ?? '');
        }
        final tot = await buildCarTotals();
        await HomeWidget.saveWidgetData<String>('tot_7d', tot.d7);
        await HomeWidget.saveWidgetData<String>('tot_mes', tot.mes);
        await HomeWidget.saveWidgetData<String>('tot_ano', tot.ano);
        // buildCarSeries va en su PROPIO try con log: metida en el try mudo de
        // arriba, cualquier excepcion suya desaparecia sin dejar rastro y las
        // tres claves simplemente no se escribian. Asi es imposible saber por
        // que el selector del coche no tenia datos.
        try {
          final ser = await buildCarSeries();
          await HomeWidget.saveWidgetData<String>('hist_dias', ser.dias);
          await HomeWidget.saveWidgetData<String>('hist_semanas', ser.semanas);
          await HomeWidget.saveWidgetData<String>('hist_meses', ser.meses);
          await CarLogBridge.log('SERIES dias=' + ser.dias.length.toString() +
              ' sem=' + ser.semanas.length.toString() +
              ' mes=' + ser.meses.length.toString());
          if (ser.dias.isNotEmpty) {
            await CarLogBridge.log('SERIES muestra=' +
                (ser.dias.length > 120 ? ser.dias.substring(0, 120) : ser.dias));
          }
        } catch (e) {
          await CarLogBridge.log('SERIES FALLO: ' + e.toString());
        }
      } catch (e) {
        await CarLogBridge.log('TOTALES FALLO: ' + e.toString());
      }
      await HomeWidget.saveWidgetData<String>('cycle_days', dayParts.join(','));
      // El lado Kotlin llevaba 430 y 15,6 escritos a mano, asi que Android Auto
      // seguia mostrando el objetivo del B10 aunque el perfil fuera otro coche.
      await HomeWidget.saveWidgetData<String>(
          'max_range_km', gMaxRangeKm.round().toString());
      await HomeWidget.saveWidgetData<String>('bat_kwh', gBatteryKwh.toString());
      await HomeWidget.saveWidgetData<String>('tyre_size', gTyreSize);
      await HomeWidget.saveWidgetData<String>('tyre_size_r', gTyreSizeR);
      await HomeWidget.saveWidgetData<String>(
          'tyre_bar_r', gTyreBarR > 0 ? gTyreBarR.toString() : '');
      await HomeWidget.saveWidgetData<String>(
          'tyre_bar', gTyreBar > 0 ? gTyreBar.toString() : '');
      await HomeWidget.saveWidgetData<String>('bat_chem', gChemistry);
      await HomeWidget.saveWidgetData<String>('bat_dc_kw', gDcKw.toString());
      await HomeWidget.saveWidgetData<String>('bat_ac_kw', gAcKw.toString());
      // Limite de carga y horario ya vienen en config.3 del propio payload,
      // sin peticion aparte. Se reenvian para la pantalla del coche.
      try {
        final cfg = (s.raw['config'] as Map?)?['3'] as Map?;
        if (cfg != null) {
          await HomeWidget.saveWidgetData<String>(
              'charge_limit', cfg['percent']?.toString() ?? '');
          await HomeWidget.saveWidgetData<String>(
              'charge_window',
              (cfg['beginTime']?.toString() ?? '') + '-' +
                  (cfg['endTime']?.toString() ?? ''));
        }
      } catch (_) {}
      await HomeWidget.saveWidgetData<String>('target_kwh100',
          (gBatteryKwh / gMaxRangeKm * 100.0).toStringAsFixed(1));
      if (avgPct != null) {
        final kwh100 = avgPct / 100.0 * gBatteryKwh;
        // Cap a la autonomia fisica del coche: con pocos datos el consumo
        // medio sale optimista y daria autonomias imposibles (>430).
        final estRangeRaw = kwh100 > 0 ? (gBatteryKwh / kwh100 * 100).round() : 0;
        final estRange = estRangeRaw > gMaxRangeKm.round() ? gMaxRangeKm.round() : estRangeRaw;
        await HomeWidget.saveWidgetData<String>('cycle_kwh100', kwh100.toStringAsFixed(1));
        await HomeWidget.saveWidgetData<String>('cycle_est_range', estRange.toString());
      } else {
        await HomeWidget.saveWidgetData<String>('cycle_kwh100', '');
        await HomeWidget.saveWidgetData<String>('cycle_est_range', '');
      }
    }
  } catch (_) {}
  // Grafico de consumo diario + info de carga (widget_chart.dart)
  try {
    final precioW = await EnergyPrice.load();
    final extras = await buildWidgetExtras(
        isCharging: s.isCharging,
        socPercent: s.preciseSoc ?? s.soc?.toDouble(),
        eurKwh: precioW?.eurKwh);
    // Gasto en euros: se engancha al final del grafico de texto del widget
    // (TextView monoespaciado con wrap_content, asi que crecer no rompe nada)
    // y se guarda aparte para la pantalla de Consumo del coche.
    try {
      final coste = await buildCostLines();
      if (coste.widget.isNotEmpty) {
        final ct = extras['chartText'] ?? '';
        extras['chartText'] =
            ct.isEmpty ? coste.widget : ct + '\n' + coste.widget;
      }
      await HomeWidget.saveWidgetData<String>('cost_row', coste.car);
    } catch (_) {}
    for (final entry in extras.entries) {
      await HomeWidget.saveWidgetData<String>(entry.key, entry.value);
    }
  } catch (_) {
    // El grafico nunca debe romper el refresco del widget
  }
  try {
    final favs = await RoutineStore.favorites();
    await HomeWidget.saveWidgetData<String>('fav1_id', favs.isNotEmpty ? favs[0].id : '');
    await HomeWidget.saveWidgetData<String>('fav1_name', favs.isNotEmpty ? favs[0].name : '');
    await HomeWidget.saveWidgetData<String>('fav2_id', favs.length > 1 ? favs[1].id : '');
    await HomeWidget.saveWidgetData<String>('fav2_name', favs.length > 1 ? favs[1].name : '');
  } catch (_) {}
  await HomeWidget.updateWidget(androidName: 'BatteryWidgetProvider');
}

extension _TimeOfDayFormat on TimeOfDay {
  String format24Hour() => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}


class ChargeSession {
  final int startTs;
  int? endTs;
  final double startSoc;
  double? endSoc;

  ChargeSession({required this.startTs, this.endTs, required this.startSoc, this.endSoc});

  Map<String, dynamic> toMap() => {'startTs': startTs, 'endTs': endTs, 'startSoc': startSoc, 'endSoc': endSoc};
  factory ChargeSession.fromMap(Map<String, dynamic> m) => ChargeSession(
        startTs: m['startTs'] as int,
        endTs: m['endTs'] as int?,
        startSoc: (m['startSoc'] as num).toDouble(),
        endSoc: (m['endSoc'] as num?)?.toDouble(),
      );
}

class ChargeHistoryStore {
  static const _key = 'lm_charge_history_v1';
  static const _maxSessions = 25;

  static Future<List<ChargeSession>> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return [];
    try {
      final all = (json.decode(raw) as List).map((e) => ChargeSession.fromMap(Map<String, dynamic>.from(e as Map))).toList();
      // chargeState parpadea (regeneracion, enchufado sin cargar...):
      // se ocultan sesiones cerradas que fueron parpadeos: menos de 3 min
      // enchufado O ganancia de SoC despreciable (< 0.3%). Asi una carga
      // corta real (p. ej. 1% en 20 min) SI cuenta.
      return all.where((s) {
        if (s.endTs == null) return true;
        final gain = (s.endSoc ?? s.startSoc) - s.startSoc;
        final mins = (s.endTs! - s.startTs) / 60000.0;
        return gain >= 0.3 && mins >= 3.0;
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveAll(List<ChargeSession> sessions) async {
    final trimmed = sessions.length > _maxSessions ? sessions.sublist(sessions.length - _maxSessions) : sessions;
    await _storage.write(key: _key, value: json.encode(trimmed.map((s) => s.toMap()).toList()));
  }

  static Future<void> startSession(double soc) async {
    final sessions = await load();
    // Si quedo una sesion abierta (p. ej. el TCU se durmio y no vimos el fin),
    // se cierra con su ultimo SoC conocido ANTES de abrir la nueva. Antes esto
    // bloqueaba y descartaba en silencio todas las cargas siguientes.
    if (sessions.isNotEmpty && sessions.last.endTs == null) {
      final open = sessions.last;
      final gain = soc - open.startSoc;
      final mins = (DateTime.now().millisecondsSinceEpoch - open.startTs) / 60000.0;
      if (gain >= 0.3 && mins >= 3.0) {
        open.endTs = DateTime.now().millisecondsSinceEpoch;
        open.endSoc = soc;
        await HistoryArchive.appendCharge(open.startTs, open.endTs!, open.startSoc, soc);
      } else {
        sessions.removeLast();
      }
      await _saveAll(sessions);
    }
    final fresh = await load();
    fresh.add(ChargeSession(startTs: DateTime.now().millisecondsSinceEpoch, startSoc: soc));
    await _saveAll(fresh);
  }

  /// Cierra una sesion huerfana (quedo abierta porque el sueno del TCU impidio
  /// ver el fin de la carga). Se llama en CADA refresco, antes de la deteccion
  /// normal. Cierra por evidencia; el tiempo es solo red de seguridad.
  static Future<void> reconcileOpenSession({
    required bool isPluggedIn,
    required bool chargeCompleted,
    required double? currentSoc,
  }) async {
    final sessions = await load();
    if (sessions.isEmpty || sessions.last.endTs != null) return;
    final open = sessions.last;
    final ageH =
        (DateTime.now().millisecondsSinceEpoch - open.startTs) / 3600000.0;
    final shouldClose = !isPluggedIn || chargeCompleted || ageH > 12.0;
    if (!shouldClose) return;
    final endSoc = currentSoc ?? open.startSoc;
    final gain = endSoc - open.startSoc;
    final mins = (DateTime.now().millisecondsSinceEpoch - open.startTs) / 60000.0;
    if (gain >= 0.3 && mins >= 3.0) {
      open.endTs = DateTime.now().millisecondsSinceEpoch;
      open.endSoc = endSoc;
      await _saveAll(sessions);
      await HistoryArchive.appendCharge(open.startTs, open.endTs!, open.startSoc, endSoc);
    } else {
      sessions.removeLast();
      await _saveAll(sessions);
    }
  }

  static Future<void> endSession(double soc) async {
    final sessions = await load();
    if (sessions.isEmpty || sessions.last.endTs != null) return;
    final s = sessions.last;
    if (soc - s.startSoc < 1.0) {
      // Parpadeo de chargeState: no es una carga real, se descarta.
      sessions.removeLast();
      await _saveAll(sessions);
      return;
    }
    s.endTs = DateTime.now().millisecondsSinceEpoch;
    s.endSoc = soc;
    await _saveAll(sessions);
    await HistoryArchive.appendCharge(s.startTs, s.endTs!, s.startSoc, soc);
  }
}

class TripPoint {
  final int ts;
  final int totalMileage;
  final double soc;
  TripPoint({required this.ts, required this.totalMileage, required this.soc});

  Map<String, dynamic> toMap() => {'ts': ts, 'km': totalMileage, 'soc': soc};
  factory TripPoint.fromMap(Map<String, dynamic> m) =>
      TripPoint(ts: m['ts'] as int, totalMileage: m['km'] as int, soc: (m['soc'] as num).toDouble());
}

class TripPointStore {
  static const _key = 'lm_trip_points_v1';
  static const _maxPoints = 200;

  static Future<List<TripPoint>> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return [];
    try {
      return (json.decode(raw) as List).map((e) => TripPoint.fromMap(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> addPoint(int totalMileage, double soc) async {
    final points = await load();
    final nowTs = DateTime.now().millisecondsSinceEpoch;
    points.add(TripPoint(ts: nowTs, totalMileage: totalMileage, soc: soc));
    await HistoryArchive.appendTrip(nowTs, totalMileage, soc);
    final trimmed = points.length > _maxPoints ? points.sublist(points.length - _maxPoints) : points;
    await _storage.write(key: _key, value: json.encode(trimmed.map((p) => p.toMap()).toList()));
  }

  /// Consumo medio en % de bateria por cada 100 km, calculado solo entre
  /// tramos donde el odometro avanzo Y la bateria bajo (se descarta si hubo carga
  /// de por medio, para no mezclar conduccion con recarga).
  static double? averageConsumptionPercentPer100km(List<TripPoint> points) {
    // Filtros calibrados con datos reales:
    //  - por tramo: solo se descarta lo fisicamente imposible (no sesga).
    //  - red de seguridad: si la media sale implausible, no se da dato. Un
    //    tramo con conduccion + carga sin muestrear hunde el consumo y
    //    disparaba la autonomia estimada a cifras falsas.
    const minInterval = 8.0; // %/100km imposible por debajo
    const maxInterval = 70.0; // %/100km imposible por encima
    const minAvg = 12.0; // media final creible
    const maxAvg = 70.0;
    double totalKm = 0;
    double totalSocDrop = 0;
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final kmDelta = (curr.totalMileage - prev.totalMileage).toDouble();
      final socDelta = prev.soc - curr.soc;
      if (kmDelta <= 0 || socDelta <= 0) continue;
      final pct = socDelta / kmDelta * 100;
      if (pct < minInterval || pct > maxInterval) continue;
      totalKm += kmDelta;
      totalSocDrop += socDelta;
    }
    if (totalKm < 5) return null;
    final avg = (totalSocDrop / totalKm) * 100;
    if (avg < minAvg || avg > maxAvg) return null;
    return avg;
  }
}

/// Tarjeta con el historial de sesiones de carga detectadas.
class ChargeHistoryCard extends StatefulWidget {
  final ChargeSession? liveOpenSession;
  const ChargeHistoryCard({super.key, this.liveOpenSession});

  @override
  State<ChargeHistoryCard> createState() => _ChargeHistoryCardState();
}

class _ChargeHistoryCardState extends State<ChargeHistoryCard> {
  List<ChargeSession> _sessions = [];
  Map<int, ChargeCost> _costes = {};
  double? _precioCasa;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ChargeHistoryCard old) {
    super.didUpdateWidget(old);
    _load();
  }

  Future<void> _load() async {
    // La deteccion en vivo casi nunca llega a ver una carga: se dispara con el
    // flanco de isCharging y exige sondear mientras el coche esta enchufado,
    // algo que Doze impide de madrugada. Se toman las cargas CERRADAS de la
    // reconstruccion sobre trips.jsonl y de la deteccion en vivo se conserva
    // solo la sesion abierta, si la hubiera.
    final live = await ChargeHistoryStore.load();
    final open = live.where((s) => s.endTs == null).toList();
    final rebuilt = await ChargeRebuild.fromTrips();
    final closed = rebuilt
        .map((r) => ChargeSession(
              startTs: r.startTs,
              endTs: r.endTs,
              startSoc: r.startSoc,
              endSoc: r.endSoc,
            ))
        .toList();
    final all = <ChargeSession>[...closed, ...open];
    final costes = await ChargeCostStore.loadAll();
    final precio = await EnergyPrice.load();
    if (mounted) {
      setState(() {
        _sessions = all.reversed.take(8).toList();
        _costes = costes;
        _precioCasa = precio?.eurKwh;
      });
    }
  }

  /// Etiqueta de coste, tocable. La tilde delante avisa de que es una
  /// estimacion con el precio de casa y no un dato confirmado.
  Widget _chipCoste(ChargeSession s, Color textColor) {
    final kwh =
        ((s.endSoc ?? s.startSoc) - s.startSoc) / 100.0 * gBatteryKwh;
    final manual = _costes[s.startTs];
    var estimado = false;
    final eur = costeCarga(
      kwhBateria: kwh,
      manual: manual,
      precioCasa: _precioCasa,
      marca: (e) => estimado = e,
    );
    final texto = eur == null
        ? '+ €'
        : (estimado ? '~' : '') +
            eur.toStringAsFixed(2).replaceAll('.', ',') +
            ' €';
    return InkWell(
      onTap: () async {
        final cambiado =
            await editarCosteCarga(context, s.startTs, kwh, manual);
        if (cambiado) await _load();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          border: Border.all(color: textColor.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          texto,
          style: TextStyle(
            color: textColor,
            fontSize: 11,
            fontWeight: estimado ? FontWeight.normal : FontWeight.bold,
            fontStyle: estimado ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ),
    );
  }

  String _fmtDate(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFBFE0FA);
    const textColor = Color(0xFF0D3B66);

    return Container(
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.chargeHistoryTitle, style: const TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 15)),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context)!.chargeHistorySubtitle,
            style: const TextStyle(color: textColor, fontSize: 10),
          ),
          Text(
            Localizations.localeOf(context).languageCode == 'es'
                ? 'Reconstruido del historial de bateria: la duracion y la potencia no se miden. Toca el precio para corregirlo; en cursiva es estimado.'
                : 'Rebuilt from battery history: duration and power are not measured. Tap a price to correct it; italics means estimated.',
            style: const TextStyle(
                color: textColor, fontSize: 10, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 8),
          if (_sessions.isEmpty)
            Text(AppLocalizations.of(context)!.noChargeDetected, style: const TextStyle(color: textColor, fontSize: 12))
          else
            ..._sessions.map((s) {
              final ongoing = s.endTs == null;
              final endLabel = ongoing ? AppLocalizations.of(context)!.ongoingLabel : '${s.endSoc?.toStringAsFixed(0)}%';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(ongoing ? Icons.bolt : Icons.check_circle_outline, size: 15, color: textColor),
                    const SizedBox(width: 6),
                    Text(_fmtDate(s.startTs), style: const TextStyle(color: textColor, fontSize: 12)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ongoing
                            ? '${s.startSoc.toStringAsFixed(0)}% -> $endLabel'
                            : '${s.startSoc.toStringAsFixed(0)}% -> $endLabel  -  +${(((s.endSoc ?? s.startSoc) - s.startSoc) / 100.0 * gBatteryKwh).toStringAsFixed(1)} kWh',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (!ongoing) _chipCoste(s, textColor),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// Tarjeta de consumo medio y comparacion con la autonomia reportada por el coche.
class ConsumptionCard extends StatefulWidget {
  final int? reportedRange;
  final double? currentSoc;
  const ConsumptionCard({super.key, required this.reportedRange, required this.currentSoc});

  @override
  State<ConsumptionCard> createState() => _ConsumptionCardState();
}

class _ConsumptionCardState extends State<ConsumptionCard> {
  double? _avgPercentPer100km;
  int _pointCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ConsumptionCard old) {
    super.didUpdateWidget(old);
    _load();
  }

  Future<void> _load() async {
    final points = await TripPointStore.load();
    final avg = TripPointStore.averageConsumptionPercentPer100km(points);
    if (mounted) setState(() { _avgPercentPer100km = avg; _pointCount = points.length; });
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFBFE0FA);
    const textColor = Color(0xFF0D3B66);

    int? estimatedRange;
    if (_avgPercentPer100km != null && _avgPercentPer100km! > 0 && widget.currentSoc != null) {
      estimatedRange = ((widget.currentSoc! / _avgPercentPer100km!) * 100).round();
    }

    return Container(
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.consumptionCardTitle, style: const TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 15)),
          const SizedBox(height: 8),
          if (_avgPercentPer100km == null)
            Text(
              _pointCount < 2
                  ? AppLocalizations.of(context)!.collectingDataMsg(_pointCount)
                  : AppLocalizations.of(context)!.notEnoughDataMsg,
              style: const TextStyle(color: textColor, fontSize: 12),
            )
          else ...[
            Text(AppLocalizations.of(context)!.avgConsumptionLabel(_avgPercentPer100km!.toStringAsFixed(1)), style: const TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            if (estimatedRange != null)
              Text(AppLocalizations.of(context)!.estimatedRangeLabel(estimatedRange!), style: const TextStyle(color: textColor, fontSize: 12)),
            if (widget.reportedRange != null)
              Text(AppLocalizations.of(context)!.reportedRangeLabel(widget.reportedRange!), style: const TextStyle(color: textColor, fontSize: 12)),
            if (estimatedRange != null && widget.reportedRange != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  estimatedRange! < widget.reportedRange!
                      ? AppLocalizations.of(context)!.worseEfficiencyMsg
                      : AppLocalizations.of(context)!.betterEfficiencyMsg,
                  style: const TextStyle(color: textColor, fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ),
          ],
        ],
      ),
    );
  }
}



class PowerCard extends StatelessWidget {
  final VehicleStatus status;
  const PowerCard({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    final kw = status.batteryPowerKw;
    const textColor = Color(0xFF0D3B66);
    if (kw == null) return const SizedBox.shrink();

    // La interpretacion la decide el ESTADO del coche, no la magnitud.
    //
    // Antes se clasificaba solo por kW, asi que con el coche aparcado y 1,1 kW
    // de consumo parasito la tarjeta decia "Consumo eficiente" — que no
    // significa nada, porque no hay nada que estar conduciendo. Y con el coche
    // quieto "Regenerando" es fisicamente imposible: no hay ruedas girando.
    //
    // Ademas, el `sign` de antes devolvia cadena vacia en las DOS ramas, asi
    // que el signo nunca llegaba a pintarse.
    // El TCU duerme unos 13 minutos despues de cerrar el coche, y a partir de
    // ahi la nube devuelve el ULTIMO estado conocido: speed, gearStatus y
    // vehicleState envejecen todos juntos. Por eso la version anterior decia
    // "consumo bajo en marcha" con el coche aparcado en el garaje: leia una
    // velocidad de horas antes.
    //
    // Ningun campo del payload salva esto, asi que la regla es no afirmar
    // contexto si el dato no es reciente. La edad viene en el propio snapshot,
    // en signal.sts (milisegundos).
    int? edadTmp;
    final sig = status.raw['signal'];
    if (sig is Map) {
      final t = sig['sts'] ?? sig['1'];
      final ms = t is num ? t.toInt() : (t is String ? int.tryParse(t) : null);
      if (ms != null && ms > 1000000000000) {
        edadTmp = DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(ms))
            .inMinutes;
      }
    }
    final int edad = edadTmp ?? -1;
    final fresco = edad >= 0 && edad < 15;

    String edadTxt() {
      if (edad < 0) return '';
      if (edad < 60) return (es ? 'hace ' : '') + edad.toString() + (es ? ' min' : ' min ago');
      final h = edad ~/ 60;
      if (h < 24) return (es ? 'hace ' : '') + h.toString() + (es ? ' h' : ' h ago');
      return (es ? 'hace ' : '') + (h ~/ 24).toString() + (es ? ' d' : ' d ago');
    }

    final enMarcha = fresco && (status.speed ?? 0) > 1.0;
    final enchufado = status.isPluggedIn;
    final abs = kw.abs();
    final obj = (gMaxRangeKm > 0) ? gBatteryKwh / gMaxRangeKm * 100.0 : 0.0;
    final kmPorHora = obj > 0 ? (abs * 100.0 / obj) : 0.0;

    Color c;
    String note;
    String detalle;
    if (!fresco) {
      final e = edadTxt();
      c = const Color(0xFF5B87AC);
      note = (es ? 'Ultimo dato conocido' : 'Last known value') +
          (e.isEmpty ? '' : ', ' + e);
      detalle = es
          ? 'El coche no esta respondiendo ahora mismo, asi que no se puede saber si estaba en marcha, parado o cargando cuando se midio este valor.'
          : 'The car is not responding right now, so there is no way to tell whether it was moving, parked or charging when this was measured.';
    } else if (enchufado) {
      c = const Color(0xFF2A6FD0);
      note = es ? 'Entrando en la bateria' : 'Going into the battery';
      detalle = es
          ? 'El coche esta enchufado.'
          : 'The car is plugged in.';
    } else if (enMarcha && kw < -0.2) {
      c = const Color(0xFF2A6FD0);
      note = es ? 'Regenerando al frenar' : 'Regenerating while braking';
      detalle = es
          ? 'El motor devuelve energia a la bateria en lugar de perderla en los frenos.'
          : 'The motor is returning energy to the battery instead of wasting it as heat.';
    } else if (enMarcha) {
      if (abs <= 10) {
        c = const Color(0xFF2A9D8F);
        note = es ? 'Consumo bajo en marcha' : 'Low draw while driving';
      } else if (abs <= 30) {
        c = const Color(0xFFE9A23B);
        note = es ? 'Consumo medio en marcha' : 'Medium draw while driving';
      } else {
        c = const Color(0xFFE76F51);
        note = es ? 'Consumo alto en marcha' : 'High draw while driving';
      }
      detalle = kmPorHora > 0
          ? (es
              ? 'A este ritmo sostenido gastarias la autonomia de unos ${kmPorHora.round()} km cada hora.'
              : 'Held steady, this would use about ${kmPorHora.round()} km of range per hour.')
          : (es ? 'Potencia que sale de la bateria ahora mismo.' : 'Power leaving the battery right now.');
    } else {
      // Coche parado y sin enchufar: clima, gestion termica, electronica.
      // Aqui NO se juzga la eficiencia, porque no se esta conduciendo.
      c = abs > 3 ? const Color(0xFFE9A23B) : const Color(0xFF2A9D8F);
      note = es ? 'Consumo con el coche parado' : 'Draw while parked';
      detalle = kmPorHora > 0
          ? (es
              ? 'Climatizacion, gestion termica de la bateria y electronica. A este ritmo perderias unos ${kmPorHora.round()} km de autonomia por hora.'
              : 'Climate, battery thermal management and electronics. At this rate you would lose about ${kmPorHora.round()} km of range per hour.')
          : (es
              ? 'Climatizacion, gestion termica de la bateria y electronica.'
              : 'Climate, battery thermal management and electronics.');
    }
    final valueStr = '${abs.toStringAsFixed(1)} kW';

    return Container(
      decoration: BoxDecoration(color: const Color(0xFFBFE0FA), borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(es ? 'Potencia de bateria' : 'Battery power',
              style: const TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 15)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon((enchufado || kw < -0.2) ? Icons.battery_charging_full : Icons.bolt,
                  color: c, size: 30),
              const SizedBox(width: 8),
              Text(valueStr, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 26)),
            ],
          ),
          const SizedBox(height: 4),
          Text(note, style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 2),
          const SizedBox(height: 4),
          Text(detalle, style: const TextStyle(color: textColor, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            es
                ? 'Es una foto puntual, no un promedio.'
                : 'A single reading, not an average.',
            style: const TextStyle(color: textColor, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class TirePressureCard extends StatelessWidget {
  final VehicleStatus status;
  const TirePressureCard({super.key, required this.status});

  String _bar(int? kpa) => kpa == null ? '--' : (kpa / 100).toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFBFE0FA);
    const textColor = Color(0xFF0D3B66);

    Widget tile(String label, int? kpa) => Expanded(
          child: Column(
            children: [
              Text(AppLocalizations.of(context)!.barUnit(_bar(kpa)), style: const TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
              Text(label, style: const TextStyle(color: textColor, fontSize: 11)),
            ],
          ),
        );

    return Container(
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLocalizations.of(context)!.tirePressureTitle, style: const TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 15)),
          const SizedBox(height: 10),
          Row(children: [
            tile(AppLocalizations.of(context)!.tireFrontLeft, status.leftFrontTireKpa),
            tile(AppLocalizations.of(context)!.tireFrontRight, status.rightFrontTireKpa),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            tile(AppLocalizations.of(context)!.tireRearLeft, status.leftRearTireKpa),
            tile(AppLocalizations.of(context)!.tireRearRight, status.rightRearTireKpa),
          ]),
          if (status.tirePressureAlerts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE76F51),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (Localizations.localeOf(context).languageCode == 'es'
                              ? 'Revisa la presion: '
                              : 'Check pressure: ') +
                          status.tirePressureAlerts.join(', '),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}



class _Charger {
  final double lat;
  final double lon;
  final String name;
  final String? operator;
  final String? power;
  _Charger(this.lat, this.lon, this.name, this.operator, this.power);
}

class FullMapScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  const FullMapScreen({super.key, required this.latitude, required this.longitude});

  @override
  State<FullMapScreen> createState() => _FullMapScreenState();
}

class _FullMapScreenState extends State<FullMapScreen> {
  List<_Charger> _chargers = [];
  bool _loading = false;
  bool _tried = false;

  @override
  void initState() {
    super.initState();
    _loadChargers();
  }

  Future<void> _loadChargers() async {
    setState(() => _loading = true);
    try {
      final lat = widget.latitude, lon = widget.longitude;
      final q =
          '[out:json][timeout:20];node["amenity"="charging_station"](around:5000,$lat,$lon);out body 60;';
      final uri = Uri.parse('https://overpass-api.de/api/interpreter');
      final resp = await plain_http.post(uri,
          headers: {'User-Agent': 'LMB10-app (uso personal)'},
          body: {'data': q}).timeout(const Duration(seconds: 25));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final els = (data['elements'] as List?) ?? [];
        final list = <_Charger>[];
        for (final e in els) {
          final m = Map<String, dynamic>.from(e as Map);
          final la = (m['lat'] as num?)?.toDouble();
          final lo = (m['lon'] as num?)?.toDouble();
          if (la == null || lo == null) continue;
          final tags = Map<String, dynamic>.from(m['tags'] ?? {});
          final name = (tags['name'] ?? tags['operator'] ?? 'Punto de carga').toString();
          final op = tags['operator']?.toString();
          final power = (tags['maxpower'] ?? tags['socket:type2:output'] ?? tags['charging_station:output'])?.toString();
          list.add(_Charger(la, lo, name, op, power));
        }
        if (mounted) setState(() => _chargers = list);
      }
    } catch (_) {
    }
    if (mounted) setState(() { _loading = false; _tried = true; });
  }

  Future<void> _navigateTo(_Charger c) async {
    final es = Localizations.localeOf(context).languageCode == 'es';
    // Google Maps web/app: el esquema https siempre resuelve si hay navegador
    // o Maps. Intentamos primero geo: (app de mapas), luego el enlace web.
    final geo = Uri.parse('geo:${c.lat},${c.lon}?q=${c.lat},${c.lon}(${Uri.encodeComponent(c.name)})');
    final web = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${c.lat},${c.lon}');
    try {
      final okGeo = await launchUrl(geo, mode: LaunchMode.externalApplication);
      if (okGeo) return;
    } catch (_) {}
    try {
      await launchUrl(web, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(es ? 'No se pudo abrir la navegacion' : 'Could not open navigation')));
      }
    }
  }

  void _showCharger(_Charger c) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    final dist = Geolocator.distanceBetween(widget.latitude, widget.longitude, c.lat, c.lon);
    final distStr = dist >= 1000 ? '${(dist / 1000).toStringAsFixed(1)} km' : '${dist.round()} m';
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.ev_station, color: Color(0xFF2A9D8F), size: 28),
                const SizedBox(width: 10),
                Expanded(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              ],
            ),
            const SizedBox(height: 8),
            if (c.operator != null) Text('${es ? 'Operador' : 'Operator'}: ${c.operator}'),
            if (c.power != null) Text('${es ? 'Potencia' : 'Power'}: ${c.power}'),
            Text('${es ? 'Distancia' : 'Distance'}: $distStr'),
            const SizedBox(height: 4),
            Text(
              es ? 'Datos de OpenStreetMap. Sin disponibilidad en vivo.' : 'OpenStreetMap data. No live availability.',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () { Navigator.pop(context); _navigateTo(c); },
                icon: const Icon(Icons.directions),
                label: Text(es ? 'Ir (en el movil)' : 'Go (on phone)'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    final point = LatLng(widget.latitude, widget.longitude);
    return Scaffold(
      appBar: AppBar(
        title: Text(es ? 'Ubicacion del vehiculo' : 'Vehicle location'),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.ev_station),
              tooltip: es ? 'Buscar cargadores' : 'Find chargers',
              onPressed: _loadChargers,
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(initialCenter: point, initialZoom: 15.0),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.txurtxil.lpb10',
              ),
              MarkerLayer(markers: [
                for (final c in _chargers)
                  Marker(
                    point: LatLng(c.lat, c.lon),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () => _showCharger(c),
                      child: const Icon(Icons.ev_station, color: Color(0xFF2A9D8F), size: 32),
                    ),
                  ),
                Marker(point: point, width: 46, height: 46, child: const Icon(Icons.directions_car, color: Colors.deepPurple, size: 38)),
              ]),
            ],
          ),
          if (_tried && _chargers.isEmpty && !_loading)
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    es ? 'Sin cargadores mapeados cerca' : 'No mapped chargers nearby',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}



class _AddressCache {
  static double? _lastLat;
  static double? _lastLon;
  static String? _lastAddress;

  static const _kLat = 'addr_lat_v1';
  static const _kLon = 'addr_lon_v1';
  static const _kTxt = 'addr_txt_v1';

  /// La cache era SOLO estatica en memoria, y el refresco de fondo corre en
  /// OTRO isolate con sus propias estaticas: para el siempre estaba vacia. Si
  /// se llama desde ahi sin persistir, cada refresco de WorkManager seria una
  /// peticion a Nominatim cada 15 minutos por cada usuario, que es exactamente
  /// el uso automatizado que su politica prohibe. Persistida, la regla de los
  /// 300 m funciona entre isolates y solo se llama al mover el coche.
  static Future<void> _cargarSiHaceFalta() async {
    if (_lastAddress != null) return;
    try {
      final t = await _storage.read(key: _kTxt);
      final la = double.tryParse(await _storage.read(key: _kLat) ?? '');
      final lo = double.tryParse(await _storage.read(key: _kLon) ?? '');
      if (t != null && t.isNotEmpty && la != null && lo != null) {
        _lastAddress = t;
        _lastLat = la;
        _lastLon = lo;
      }
    } catch (_) {}
  }

  static Future<void> _guardar(String txt, double lat, double lon) async {
    try {
      await _storage.write(key: _kTxt, value: txt);
      await _storage.write(key: _kLat, value: lat.toString());
      await _storage.write(key: _kLon, value: lon.toString());
    } catch (_) {}
  }

  static Future<String> resolve(double lat, double lon) async {
    await _cargarSiHaceFalta();
    // Solo vuelve a consultar Nominatim si el coche se movio > ~300 metros,
    // para respetar su politica de uso (evitar peticiones repetidas cada 90s).
    if (_lastAddress != null && _lastLat != null && _lastLon != null) {
      final movedMeters = Geolocator.distanceBetween(_lastLat!, _lastLon!, lat, lon);
      if (movedMeters < 300) return _lastAddress!;
    }
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lon&zoom=16&addressdetails=1',
      );
      await CarLogBridge.log('NOMINATIM peticion lat=' +
          lat.toStringAsFixed(4) + ' lon=' + lon.toStringAsFixed(4));
      final response = await plain_http.get(uri, headers: {'User-Agent': 'LMB10-app (uso personal)'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;
        final road = address?['road']?.toString();
        final suburb = address?['suburb']?.toString() ?? address?['city_district']?.toString();
        final resolved = road != null
            ? (suburb != null ? '$road, $suburb' : road)
            : (data['display_name']?.toString().split(',').take(2).join(',') ?? 'Ubicacion desconocida');
        _lastAddress = resolved;
        _lastLat = lat;
        _lastLon = lon;
        await _guardar(resolved, lat, lon);
        return resolved;
      }
    } catch (_) {}
    return _lastAddress ?? 'Could not resolve address';
  }
}

class LocationCard extends StatefulWidget {
  final double latitude;
  final double longitude;
  const LocationCard({super.key, required this.latitude, required this.longitude});

  @override
  State<LocationCard> createState() => _LocationCardState();
}

class _LocationCardState extends State<LocationCard> {
  String _address = '';
  String _distanceLabel = '';

  @override
  void initState() {
    super.initState();
    _loadAddress();
    _loadDistance();
  }

  @override
  void didUpdateWidget(covariant LocationCard old) {
    super.didUpdateWidget(old);
    if (old.latitude != widget.latitude || old.longitude != widget.longitude) {
      _loadAddress();
      _loadDistance();
    }
  }

  Future<void> _loadAddress() async {
    final addr = await _AddressCache.resolve(widget.latitude, widget.longitude);
    if (mounted) setState(() => _address = AppLocalizations.of(context)!.parkedNear(addr));
  }

  Future<void> _loadDistance() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _distanceLabel = AppLocalizations.of(context)!.enableLocationPermission);
        return;
      }
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _distanceLabel = AppLocalizations.of(context)!.enableGps);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      final meters = Geolocator.distanceBetween(position.latitude, position.longitude, widget.latitude, widget.longitude);
      final label = meters >= 1000 ? '${(meters / 1000).toStringAsFixed(1)} km' : '${meters.round()} m';
      if (mounted) setState(() => _distanceLabel = AppLocalizations.of(context)!.distanceFromCurrentPosition(label));
    } catch (_) {
      if (mounted) setState(() => _distanceLabel = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFBFE0FA);
    const textColor = Color(0xFF0D3B66);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => FullMapScreen(latitude: widget.latitude, longitude: widget.longitude)),
      ),
      child: Container(
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.location_on, color: textColor, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_address.isEmpty ? AppLocalizations.of(context)!.resolvingAddress : _address, style: const TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                  if (_distanceLabel.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(_distanceLabel, style: const TextStyle(color: textColor, fontSize: 11)),
                    ),
                ],
              ),
            ),
            const Icon(Icons.open_in_full, color: textColor, size: 16),
          ],
        ),
      ),
    );
  }
}


class _TileData {
  final IconData icon;
  final String value;
  final String label;
  _TileData(this.icon, this.value, this.label);
}

class _StatTile extends StatelessWidget {
  final _TileData data;
  const _StatTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(data.icon, size: 22),
          const SizedBox(height: 6),
          Text(data.value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text(data.label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}

// ============================================================
// Debug: estado completo (JSON crudo) del vehiculo, con snapshot/diff
// ============================================================
class DebugStatusScreen extends StatefulWidget {
  final LeapmotorApiClient client;
  final Vehicle vehicle;
  const DebugStatusScreen({super.key, required this.client, required this.vehicle});

  @override
  State<DebugStatusScreen> createState() => _DebugStatusScreenState();
}

class _DebugStatusScreenState extends State<DebugStatusScreen> {
  Map<String, dynamic>? _current;
  Map<String, dynamic>? _snapshot;
  String _text = 'Cargando...';
  bool _loading = false;
  bool _showingDiff = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; });
    try {
      final status = await widget.client.getVehicleStatus(widget.vehicle.vin);
      setState(() {
        _current = status.raw;
        _loading = false;
        if (_showingDiff && _snapshot != null) {
          _renderDiff();
        } else {
          const encoder = JsonEncoder.withIndent('  ');
          _text = encoder.convert(status.raw);
        }
      });
    } catch (e) {
      setState(() { _text = 'Error: $e'; _loading = false; });
    }
  }

  /// SONDA del endpoint de cargas. Vuelca el cuerpo crudo sin interpretarlo:
  /// se desconoce si chargeInEnergy viene en kWh o Wh, y si los timestamps del
  /// conector son segundos o milisegundos. Se decide viendo la respuesta real.
  /// SONDA del PVPC. Vuelca la respuesta CRUDA de Red Electrica sin
  /// interpretarla: no esta confirmado el nombre exacto del endpoint, ni la
  /// estructura de "included", ni si el valor viene con impuestos incluidos.
  /// Se decide viendo la respuesta, no adivinando.
  Future<void> _probePvpc() async {
    setState(() {
      _loading = true;
      _showingDiff = false;
      _text = 'Consultando precios de Red Electrica...';
    });
    final buf = StringBuffer();
    final hoy = DateTime.now();
    String d(DateTime x) => x.year.toString().padLeft(4, '0') + '-' +
        x.month.toString().padLeft(2, '0') + '-' +
        x.day.toString().padLeft(2, '0');

    for (final prueba in [
      ['REData precios-mercados-tiempo-real',
       'https://apidatos.ree.es/es/datos/mercados/precios-mercados-tiempo-real'
           '?start_date=' + d(hoy) + 'T00:00&end_date=' + d(hoy) +
           'T23:59&time_trunc=hour&geo_limit=peninsula'],
      ['REData sin geo_limit',
       'https://apidatos.ree.es/es/datos/mercados/precios-mercados-tiempo-real'
           '?start_date=' + d(hoy) + 'T00:00&end_date=' + d(hoy) +
           'T23:59&time_trunc=hour'],
      ['preciodelaluz.org (alternativa sin token)',
       'https://api.preciodelaluz.org/v1/prices/all?zone=PCB'],
    ]) {
      buf.writeln('### ' + prueba[0]);
      try {
        final r = await plain_http
            .get(Uri.parse(prueba[1]), headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 15));
        var cuerpo = r.body;
        if (cuerpo.length > 1400) cuerpo = cuerpo.substring(0, 1400) + '...(recortado)';
        buf.writeln('HTTP ' + r.statusCode.toString());
        buf.writeln(cuerpo);
      } catch (e) {
        buf.writeln('EXCEPCION: ' + e.toString());
      }
      buf.writeln('');
    }
    if (mounted) setState(() { _text = buf.toString(); _loading = false; });
  }

  Future<void> _probeCharges() async {
    setState(() {
      _loading = true;
      _showingDiff = false;
      _text = 'Consultando historial de cargas en la nube...';
    });
    try {
      final raw = await widget.client.probeChargeHistoryRaw(widget.vehicle.vin);
      setState(() { _text = raw; _loading = false; });
    } catch (e) {
      setState(() { _text = 'Error en la sonda de cargas:\n\n$e'; _loading = false; });
    }
  }

  void _saveSnapshot() {
    if (_current == null) return;
    setState(() {
      _snapshot = Map<String, dynamic>.from(_current!);
      _showingDiff = false;
      _text = 'Snapshot guardado (${_snapshot!.length} campos). Ejecuta ahora el comando en Controles, vuelve aqui y pulsa "Comparar con snapshot".';
    });
  }

  void _renderDiff() {
    if (_snapshot == null || _current == null) return;
    final allKeys = {..._snapshot!.keys, ..._current!.keys}.toList()..sort();
    final buf = StringBuffer();
    var changedCount = 0;
    for (final key in allKeys) {
      final before = _snapshot![key];
      final after = _current![key];
      final beforeStr = before is Map ? '(objeto anidado, omitido)' : before.toString();
      final afterStr = after is Map ? '(objeto anidado, omitido)' : after.toString();
      if (before is Map || after is Map) continue; // el sub-mapa "signal" y "config" se listan aparte abajo
      if (beforeStr != afterStr) {
        changedCount++;
        buf.writeln('$key:');
        buf.writeln('  antes:   $beforeStr');
        buf.writeln('  despues: $afterStr');
        buf.writeln();
      }
    }
    // Tambien diffear dentro de "signal" (los IDs numericos crudos), que es donde
    // pueden aparecer campos que aun no tenemos mapeados a nombre legible.
    final beforeSignal = (_snapshot!['signal'] as Map?) ?? {};
    final afterSignal = (_current!['signal'] as Map?) ?? {};
    final signalKeys = {...beforeSignal.keys, ...afterSignal.keys}.toList()
      ..sort((a, b) => a.toString().compareTo(b.toString()));
    for (final key in signalKeys) {
      final b = beforeSignal[key];
      final a = afterSignal[key];
      if (b.toString() != a.toString()) {
        changedCount++;
        buf.writeln('signal.$key:');
        buf.writeln('  antes:   $b');
        buf.writeln('  despues: $a');
        buf.writeln();
      }
    }
    setState(() {
      _showingDiff = true;
      _text = changedCount == 0
          ? 'Sin cambios: ningun campo (ni en signal) vario respecto al snapshot guardado.'
          : '$changedCount campo(s) cambiaron respecto al snapshot:\n\n${buf.toString()}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.debugScreenTitle),
        actions: [
          IconButton(
            icon: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _current == null ? null : _saveSnapshot,
                    child: Text(AppLocalizations.of(context)!.saveSnapshotButton),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _snapshot == null ? null : _renderDiff,
                    child: Text(AppLocalizations.of(context)!.compareSnapshotButton),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _loading ? null : _probeCharges,
                icon: const Icon(Icons.ev_station_outlined, size: 18),
                label: Text(Localizations.localeOf(context).languageCode == 'es'
                    ? 'Sonda: historial de cargas (nube)'
                    : 'Probe: charge history (cloud)'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _loading ? null : _probePvpc,
                icon: const Icon(Icons.bolt_outlined, size: 18),
                label: Text(Localizations.localeOf(context).languageCode == 'es'
                    ? 'Sonda: precios PVPC (Red Electrica)'
                    : 'Probe: PVPC prices (grid operator)'),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SelectableText(_text, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Controles
// ============================================================
class ControlsScreen extends StatefulWidget {
  final LeapmotorApiClient client;
  final Vehicle vehicle;
  final String pin;
  const ControlsScreen({super.key, required this.client, required this.vehicle, required this.pin});

  @override
  State<ControlsScreen> createState() => _ControlsScreenState();
}

class _ControlsScreenState extends State<ControlsScreen> {
  bool _busy = false;
  String? _lastMessage;

  @override
  void initState() {
    super.initState();
    _loadCurrentChargeLimit();
  }

  Future<void> _loadCurrentChargeLimit() async {
    try {
      final status = await widget.client.getVehicleStatus(widget.vehicle.vin);
      final sl = (status.raw['speedLimit'] as num?)?.toDouble();
      final sa = (status.raw['speedLimitActive'] as num?)?.toInt();
      setState(() {
        _chargeLimit = (status.chargeLimitPercent ?? 100).toDouble().clamp(50, 100);
        _loadingChargeLimit = false;
        // Mismo viaje, sin peticion extra.
        if (sl != null && sl > 0) {
          _carSpeedLimit = sl;
          _speedLimit = sl.clamp(30, 150);
        }
        if (sa != null) _carSpeedActive = sa != 0;
      });
    } catch (_) {
      setState(() { _chargeLimit = 100; _loadingChargeLimit = false; });
    }
  }

  int _driverSeatHeat = 0;
  int _passengerSeatHeat = 0;
  int _driverSeatVent = 0;
  int _passengerSeatVent = 0;
  double? _chargeLimit;
  bool _loadingChargeLimit = true;
  double _speedLimit = 130;

  /// Limite de velocidad TAL COMO LO TIENE EL COCHE. El deslizador arrancaba
  /// siempre en 130 sin leer nada, asi que mostraba un valor inventado: en un
  /// coche con 110 configurados, la pantalla decia 130. Y speedLimitActive se
  /// parseaba desde la senal 12054 sin usarse en ninguna parte.
  double? _carSpeedLimit;
  bool? _carSpeedActive;

  Future<void> _run(String label, Future<void> Function() action) async {
    setState(() { _busy = true; _lastMessage = null; });
    try {
      await action();
      setState(() => _lastMessage = '$label: OK');
    } catch (e) {
      setState(() => _lastMessage = '$label: ${_friendlyError(e)}');
    } finally {
      setState(() => _busy = false);
    }
  }

  // Traduce errores crudos de la nube a mensajes utiles. "No such permission"
  // (Error 40) suele significar que la funcion no esta habilitada en el coche
  // o no la soporta este vehiculo, no que la app falle.
  String _friendlyError(Object e) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    final msg = e.toString();
    if (msg.contains('No such permission') || msg.contains('Error 40')) {
      return es
          ? 'no disponible. Puede que debas activar esta funcion en los ajustes del coche, o que tu vehiculo no la soporte.'
          : 'not available. You may need to enable this function in the car settings, or your vehicle may not support it.';
    }
    return 'Error - $e';
  }

  @override
  Widget build(BuildContext context) {
    final vin = widget.vehicle.vin;
    final pin = widget.pin;
    final c = widget.client;

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.controlsScreenTitle)),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_lastMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_lastMessage!, style: const TextStyle(color: Colors.amber)),
              ),
            // Centinela arriba del todo, para ver de inmediato el resultado del comando.
            _sectionTitle(AppLocalizations.of(context)!.sectionSentry),
            _actionGrid([
              _ActionBtn(AppLocalizations.of(context)!.actionSentryOn, Icons.security, () => _run(AppLocalizations.of(context)!.actionSentryOn, () => c.sentryModeOn(vin, pin))),
              _ActionBtn(AppLocalizations.of(context)!.actionSentryOff, Icons.gpp_bad_outlined, () => _run(AppLocalizations.of(context)!.actionSentryOff, () => c.sentryModeOff(vin, pin))),
            ]),
            _sectionTitle(AppLocalizations.of(context)!.sectionActions),
            _actionGrid([
              _ActionBtn(AppLocalizations.of(context)!.actionLock, Icons.lock, () => _run(AppLocalizations.of(context)!.actionLock, () async { await markManualLockAction(); await c.lockVehicle(vin, pin); })),
              _ActionBtn(AppLocalizations.of(context)!.actionUnlock, Icons.lock_open, () => _run(AppLocalizations.of(context)!.actionUnlock, () async { await markManualLockAction(); await c.unlockVehicle(vin, pin); })),
              _ActionBtn(AppLocalizations.of(context)!.actionTrunkOpen, Icons.inventory_2, () => _run(AppLocalizations.of(context)!.actionTrunkOpen, () => c.openTrunk(vin, pin))),
              _ActionBtn(AppLocalizations.of(context)!.actionTrunkClose, Icons.inventory_2_outlined, () => _run(AppLocalizations.of(context)!.actionTrunkClose, () => c.closeTrunk(vin, pin))),
              _ActionBtn(AppLocalizations.of(context)!.actionFindCar, Icons.location_searching, () => _run(AppLocalizations.of(context)!.actionFindCar, () => c.findVehicle(vin, pin))),
              _ActionBtn(AppLocalizations.of(context)!.actionUnlockCharger, Icons.ev_station, () => _run(AppLocalizations.of(context)!.actionUnlockCharger, () => c.unlockCharger(vin, pin))),
            ]),
            _sectionTitle(AppLocalizations.of(context)!.sectionClimate),
            _actionGrid([
              _ActionBtn(AppLocalizations.of(context)!.actionQuickHeat, Icons.whatshot, () => _run(AppLocalizations.of(context)!.actionQuickHeat, () => c.quickHeat(vin, pin))),
              _ActionBtn(AppLocalizations.of(context)!.actionQuickCool, Icons.ac_unit, () => _run(AppLocalizations.of(context)!.actionQuickCool, () => c.quickCool(vin, pin))),
              _ActionBtn(AppLocalizations.of(context)!.actionDefrost, Icons.blur_on, () => _run(AppLocalizations.of(context)!.actionDefrost, () => c.windshieldDefrost(vin, pin))),
              _ActionBtn(AppLocalizations.of(context)!.actionAcOff, Icons.power_settings_new, () => _run(AppLocalizations.of(context)!.actionAcOff, () => c.acOff(vin, pin))),
            ]),
            _sectionTitle(AppLocalizations.of(context)!.sectionComfort),
            _actionGrid([
              _ActionBtn(AppLocalizations.of(context)!.actionSteeringHeatOn, Icons.back_hand, () => _run(AppLocalizations.of(context)!.actionSteeringHeatOn, () => c.steeringWheelHeatOn(vin, pin))),
              _ActionBtn(AppLocalizations.of(context)!.actionSteeringHeatOff, Icons.back_hand_outlined, () => _run(AppLocalizations.of(context)!.actionSteeringHeatOff, () => c.steeringWheelHeatOff(vin, pin))),
            ]),
            _sectionTitle(AppLocalizations.of(context)!.sectionSunshadeWindows),
            _actionGrid([
              _ActionBtn(AppLocalizations.of(context)!.actionSunshadeOpen, Icons.blinds, () => _run(AppLocalizations.of(context)!.actionSunshadeOpen, () => c.sunshadeOpen(vin, pin))),
              _ActionBtn(AppLocalizations.of(context)!.actionSunshadeClose, Icons.blinds_closed, () => _run(AppLocalizations.of(context)!.actionSunshadeClose, () => c.sunshadeClose(vin, pin))),
              _ActionBtn(AppLocalizations.of(context)!.actionWindowsOpen, Icons.window, () => _run(AppLocalizations.of(context)!.actionWindowsOpen, () => c.windowsOpen(vin, pin))),
              _ActionBtn(AppLocalizations.of(context)!.actionWindowsClose, Icons.window_outlined, () => _run(AppLocalizations.of(context)!.actionWindowsClose, () => c.windowsClose(vin, pin))),
            ]),
            
            _sectionTitle(AppLocalizations.of(context)!.sectionSpeedLimit),
            if (_carSpeedActive != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  (Localizations.localeOf(context).languageCode == 'es'
                          ? (_carSpeedActive!
                              ? 'Activo en el coche'
                              : 'Inactivo en el coche')
                          : (_carSpeedActive!
                              ? 'Active in the car'
                              : 'Inactive in the car')) +
                      (_carSpeedLimit != null
                          ? '  -  ' + _carSpeedLimit!.round().toString() + ' km/h'
                          : ''),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _carSpeedActive!
                        ? const Color(0xFFB35A00)
                        : const Color(0xFF5B87AC),
                  ),
                ),
              ),
            Text(AppLocalizations.of(context)!.speedLimitValue(_speedLimit.round())),
            Slider(
              value: _speedLimit,
              min: 30,
              max: 150,
              divisions: 24,
              label: '${_speedLimit.round()} km/h',
              onChanged: (v) => setState(() => _speedLimit = v),
              onChangeEnd: (v) => _run('Limite de velocidad', () => c.setSpeedLimit(vin, pin, v.round())),
            ),
            Text(
              Localizations.localeOf(context).languageCode == 'es'
                  ? 'La app puede fijar el valor, pero no activar ni desactivar el limitador: eso se hace desde la pantalla del coche.'
                  : 'The app can set the value, but cannot switch the limiter on or off: that is done from the car screen.',
              style: const TextStyle(fontSize: 11, color: Color(0xFF5B87AC)),
            ),
            _sectionTitle(AppLocalizations.of(context)!.sectionBattery),
            _actionGrid([
              _ActionBtn(AppLocalizations.of(context)!.actionPreheatOn, Icons.battery_charging_full, () => _run(AppLocalizations.of(context)!.actionPreheatOn, () => c.batteryPreheatOn(vin, pin))),
              _ActionBtn(AppLocalizations.of(context)!.actionPreheatOff, Icons.battery_std, () => _run(AppLocalizations.of(context)!.actionPreheatOff, () => c.batteryPreheatOff(vin, pin))),
            ]),
            const SizedBox(height: 8),
            if (_loadingChargeLimit)
              Text(AppLocalizations.of(context)!.readingChargeLimit)
            else ...[
              Text(AppLocalizations.of(context)!.chargeLimitValue(_chargeLimit!.round())),
              Slider(
                value: _chargeLimit!,
                min: 50,
                max: 100,
                divisions: 10,
                label: '${_chargeLimit!.round()}%',
                onChanged: (v) => setState(() => _chargeLimit = v),
                onChangeEnd: (v) => _run('Limite de carga', () => c.setChargeLimit(vin, pin, v.round())),
              ),
            ],
            OutlinedButton.icon(
              icon: const Icon(Icons.edit_calendar),
              label: Text(AppLocalizations.of(context)!.editFullScheduleButton),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ChargeScheduleScreen(client: c, vehicle: widget.vehicle, pin: pin)),
                );
              },
            ),
            const SizedBox(height: 16),
            _sectionTitle(AppLocalizations.of(context)!.sectionSeats),
            _seatRow(AppLocalizations.of(context)!.seatDriverHeat, _driverSeatHeat, (v) {
              setState(() => _driverSeatHeat = v);
              _run('Asiento conductor calor', () => c.seatHeat(vin, pin, position: 3, level: v));
            }),
            _seatRow(AppLocalizations.of(context)!.seatPassengerHeat, _passengerSeatHeat, (v) {
              setState(() => _passengerSeatHeat = v);
              _run('Asiento copiloto calor', () => c.seatHeat(vin, pin, position: 2, level: v));
            }),
            _seatRow(AppLocalizations.of(context)!.seatDriverVent, _driverSeatVent, (v) {
              setState(() => _driverSeatVent = v);
              _run('Asiento conductor vent.', () => c.seatVentilation(vin, pin, position: 3, level: v));
            }),
            _seatRow(AppLocalizations.of(context)!.seatPassengerVent, _passengerSeatVent, (v) {
              setState(() => _passengerSeatVent = v);
              _run('Asiento copiloto vent.', () => c.seatVentilation(vin, pin, position: 2, level: v));
            }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      );

  Widget _actionGrid(List<_ActionBtn> actions) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: actions
          .map((a) => SizedBox(
                width: 165,
                child: ElevatedButton.icon(
                  icon: Icon(a.icon, size: 18),
                  label: Text(a.label, style: const TextStyle(fontSize: 12)),
                  onPressed: a.onTap,
                ),
              ))
          .toList(),
    );
  }

  Widget _seatRow(String label, int value, void Function(int) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          IconButton(icon: const Icon(Icons.remove), onPressed: value > 0 ? () => onChanged(value - 1) : null),
          Text('$value'),
          IconButton(icon: const Icon(Icons.add), onPressed: value < 3 ? () => onChanged(value + 1) : null),
        ],
      ),
    );
  }
}

class _ActionBtn {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  _ActionBtn(this.label, this.icon, this.onTap);
}
