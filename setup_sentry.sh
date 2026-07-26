#!/bin/bash
# ============================================================================
# LMB10 - MODO CENTINELA (Sentry Mode) - modulo completo v1.0
# Ejecutar desde la raiz del proyecto Flutter (donde esta pubspec.yaml):
#   bash setup_sentry.sh
#
# Heredocs con 'EOF' entre comillas: el simbolo $ de Dart pasa intacto.
# NO hace falta el sed de correccion de $ en este script.
#
# Que instala (lib/sentry/):
#   sentry_models.dart      - snapshot, eventos, config (JSON)
#   sentry_store.dart       - persistencia SharedPreferences (UI <-> WorkManager)
#   sentry_notifier.dart    - canal propio de notificaciones
#   sentry_adapter.dart     - UNICO punto a conectar con tu cliente API
#   sentry_engine.dart      - deteccion + cmd 220/120/110/290
#   sentry_background.dart  - 1 linea para tu callback de WorkManager
#   sentry_screen.dart      - pantalla con instrucciones integradas (es/en)
# ============================================================================
set -e
mkdir -p lib/sentry

# ----------------------------------------------------------------------------
cat > lib/sentry/sentry_models.dart << 'EOF'
// sentry_models.dart - Modelos del Modo Centinela (LMB10)

class SentrySnapshot {
  final bool? isLocked;
  final bool? anyDoorOpen;
  final bool? trunkOpen;
  final bool? anyWindowOpen;
  final bool? readyOn3; // READY / ON3 (senal 1258 en leapmotor-ha)
  final double? latitude;
  final double? longitude;
  final DateTime? collectTime; // frescura del dato TCU

  const SentrySnapshot({
    this.isLocked,
    this.anyDoorOpen,
    this.trunkOpen,
    this.anyWindowOpen,
    this.readyOn3,
    this.latitude,
    this.longitude,
    this.collectTime,
  });

  bool get hasLocation => latitude != null && longitude != null;

  Map<String, dynamic> toJson() => {
        'isLocked': isLocked,
        'anyDoorOpen': anyDoorOpen,
        'trunkOpen': trunkOpen,
        'anyWindowOpen': anyWindowOpen,
        'readyOn3': readyOn3,
        'latitude': latitude,
        'longitude': longitude,
        'collectTime': collectTime?.toIso8601String(),
      };

  factory SentrySnapshot.fromJson(Map<String, dynamic> j) => SentrySnapshot(
        isLocked: j['isLocked'] as bool?,
        anyDoorOpen: j['anyDoorOpen'] as bool?,
        trunkOpen: j['trunkOpen'] as bool?,
        anyWindowOpen: j['anyWindowOpen'] as bool?,
        readyOn3: j['readyOn3'] as bool?,
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        collectTime: j['collectTime'] == null
            ? null
            : DateTime.tryParse(j['collectTime'] as String),
      );
}

enum SentryEventType {
  armed,
  disarmed,
  nativeOn,
  nativeOff,
  nativeFailed,
  unlock,
  door,
  trunk,
  window,
  moved,
  wake,
  deterrent,
  offline,
  online,
  recOn,
  recOff,
  recFailed,
}

class SentryEvent {
  final SentryEventType type;
  final DateTime at;
  final String msg;
  final double? lat;
  final double? lon;
  final bool critical;

  SentryEvent(this.type, this.msg,
      {DateTime? at, this.lat, this.lon, this.critical = false})
      : at = at ?? DateTime.now();

  bool get hasLocation => lat != null && lon != null;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'at': at.toIso8601String(),
        'msg': msg,
        'lat': lat,
        'lon': lon,
        'critical': critical,
      };

  factory SentryEvent.fromJson(Map<String, dynamic> j) => SentryEvent(
        SentryEventType.values.byName(j['type'] as String),
        j['msg'] as String,
        at: DateTime.tryParse(j['at'] as String? ?? ''),
        lat: (j['lat'] as num?)?.toDouble(),
        lon: (j['lon'] as num?)?.toDouble(),
        critical: j['critical'] as bool? ?? false,
      );
}

class SentryConfig {
  final int pollAwakeSec; // sondeo con pantalla abierta / coche despierto
  final int freshnessMin; // dato mas viejo que esto => TCU dormido
  final double moveMeters; // deriva GPS que cuenta como "movido"
  final bool useNative; // cmd 220 al armar
  final bool useDeterrent; // claxon+luces (cmd 120) ante manipulacion
  final bool reassertLock; // reenviar cierre (cmd 110) si desbloqueo
  final int deterrentCooldownMin;

  const SentryConfig({
    this.pollAwakeSec = 30,
    this.freshnessMin = 6,
    this.moveMeters = 75,
    this.useNative = true,
    this.useDeterrent = false,
    this.reassertLock = false,
    this.deterrentCooldownMin = 2,
  });

  SentryConfig copyWith({
    int? pollAwakeSec,
    int? freshnessMin,
    double? moveMeters,
    bool? useNative,
    bool? useDeterrent,
    bool? reassertLock,
    int? deterrentCooldownMin,
  }) =>
      SentryConfig(
        pollAwakeSec: pollAwakeSec ?? this.pollAwakeSec,
        freshnessMin: freshnessMin ?? this.freshnessMin,
        moveMeters: moveMeters ?? this.moveMeters,
        useNative: useNative ?? this.useNative,
        useDeterrent: useDeterrent ?? this.useDeterrent,
        reassertLock: reassertLock ?? this.reassertLock,
        deterrentCooldownMin: deterrentCooldownMin ?? this.deterrentCooldownMin,
      );

  Map<String, dynamic> toJson() => {
        'pollAwakeSec': pollAwakeSec,
        'freshnessMin': freshnessMin,
        'moveMeters': moveMeters,
        'useNative': useNative,
        'useDeterrent': useDeterrent,
        'reassertLock': reassertLock,
        'deterrentCooldownMin': deterrentCooldownMin,
      };

  factory SentryConfig.fromJson(Map<String, dynamic> j) => SentryConfig(
        pollAwakeSec: j['pollAwakeSec'] as int? ?? 30,
        freshnessMin: j['freshnessMin'] as int? ?? 6,
        moveMeters: (j['moveMeters'] as num?)?.toDouble() ?? 75,
        useNative: j['useNative'] as bool? ?? true,
        useDeterrent: j['useDeterrent'] as bool? ?? false,
        reassertLock: j['reassertLock'] as bool? ?? false,
        deterrentCooldownMin: j['deterrentCooldownMin'] as int? ?? 2,
      );
}
EOF

# ----------------------------------------------------------------------------
cat > lib/sentry/sentry_store.dart << 'EOF'
// sentry_store.dart - Persistencia compartida entre UI y WorkManager.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'sentry_models.dart';

class SentryStore {
  static const _kArmed = 'sentry_armed';
  static const _kVin = 'sentry_vin';
  static const _kBaseline = 'sentry_baseline';
  static const _kLast = 'sentry_last';
  static const _kConfig = 'sentry_config';
  static const _kLog = 'sentry_log';
  static const _kOnline = 'sentry_online';
  static const _kDeterrentAt = 'sentry_deterrent_at';
  static const _maxLog = 200;

  Future<SharedPreferences> get _p async => SharedPreferences.getInstance();

  Future<bool> loadArmed() async => (await _p).getBool(_kArmed) ?? false;
  Future<void> saveArmed(bool v) async => (await _p).setBool(_kArmed, v);

  Future<String?> loadVin() async => (await _p).getString(_kVin);
  Future<void> saveVin(String v) async => (await _p).setString(_kVin, v);

  Future<SentrySnapshot?> _loadSnap(String key) async {
    final s = (await _p).getString(key);
    if (s == null) return null;
    try {
      return SentrySnapshot.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveSnap(String key, SentrySnapshot? snap) async {
    final p = await _p;
    if (snap == null) {
      await p.remove(key);
    } else {
      await p.setString(key, jsonEncode(snap.toJson()));
    }
  }

  Future<SentrySnapshot?> loadBaseline() => _loadSnap(_kBaseline);
  Future<void> saveBaseline(SentrySnapshot? s) => _saveSnap(_kBaseline, s);
  Future<SentrySnapshot?> loadLast() => _loadSnap(_kLast);
  Future<void> saveLast(SentrySnapshot? s) => _saveSnap(_kLast, s);

  Future<SentryConfig> loadConfig() async {
    final s = (await _p).getString(_kConfig);
    if (s == null) return const SentryConfig();
    try {
      return SentryConfig.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return const SentryConfig();
    }
  }

  Future<void> saveConfig(SentryConfig c) async =>
      (await _p).setString(_kConfig, jsonEncode(c.toJson()));

  Future<bool> loadOnline() async => (await _p).getBool(_kOnline) ?? true;
  Future<void> saveOnline(bool v) async => (await _p).setBool(_kOnline, v);

  Future<DateTime?> loadDeterrentAt() async {
    final ms = (await _p).getInt(_kDeterrentAt);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> saveDeterrentAt(DateTime t) async =>
      (await _p).setInt(_kDeterrentAt, t.millisecondsSinceEpoch);

  Future<List<SentryEvent>> loadLog() async {
    final s = (await _p).getString(_kLog);
    if (s == null) return [];
    try {
      final list = jsonDecode(s) as List<dynamic>;
      return list
          .map((e) => SentryEvent.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> appendLog(List<SentryEvent> events) async {
    if (events.isEmpty) return;
    final log = await loadLog();
    log.insertAll(0, events);
    while (log.length > _maxLog) {
      log.removeLast();
    }
    await (await _p)
        .setString(_kLog, jsonEncode(log.map((e) => e.toJson()).toList()));
  }

  Future<void> clearLog() async => (await _p).remove(_kLog);
}
EOF

# ----------------------------------------------------------------------------
cat > lib/sentry/sentry_notifier.dart << 'EOF'
// sentry_notifier.dart - Canal de notificaciones propio del Centinela.
// Funciona tambien desde el isolate de WorkManager (igual que tus avisos
// de bateria baja).

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class SentryNotifier {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _inited = false;

  static Future<void> _init() async {
    if (_inited) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings);
    _inited = true;
  }

  static Future<void> show(String title, String body,
      {bool critical = false}) async {
    await _init();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'sentry_events',
        'Modo Centinela',
        channelDescription: 'Alertas del Modo Centinela',
        importance: critical ? Importance.max : Importance.defaultImportance,
        priority: critical ? Priority.high : Priority.defaultPriority,
        category: critical ? AndroidNotificationCategory.alarm : null,
      ),
    );
    final id = DateTime.now().millisecondsSinceEpoch % 100000;
    await _plugin.show(id, title, body, details);
  }
}
EOF

# ----------------------------------------------------------------------------
cat > lib/sentry/sentry_adapter.dart << 'EOF'
// sentry_adapter.dart
// ============================================================================
// UNICO PUNTO DE INTEGRACION DEL MODULO CENTINELA.
// Conecta aqui tu cliente API ya portado (mTLS + HKDF). Son 3 ajustes:
//   (1) el import de tu cliente,
//   (2) la factoria buildSentryClient(),
//   (3) el mapeo de campos de tu VehicleStatus -> SentrySnapshot.
// El resto del modulo no se toca.
// ============================================================================

import 'sentry_models.dart';

// (1) PEGA AQUI el import de tu cliente real, por ejemplo:
// import '../services/leapmotor_client.dart';

abstract class SentryClient {
  Future<SentrySnapshot> fetchSnapshot(String vin);

  /// true si el backend acepta el comando.
  Future<bool> sendCommand(String vin, int cmdId, Map<String, dynamic> params);
}

/// (2) PEGA AQUI tu factoria. Ejemplo tipico con tu singleton de sesion:
///
///   Future<SentryClient> buildSentryClient() async {
///     final api = await LeapmotorClient.instance(); // tu clase
///     return _RealSentryClient(api);
///   }
Future<SentryClient> buildSentryClient() async {
  throw UnimplementedError(
      'Conecta tu cliente en lib/sentry/sentry_adapter.dart (bloques 1-3)');
}

/// (3) Adaptador de referencia. Descomenta y ajusta los nombres a tu modelo.
/// Los campos siguen el port 1:1 de leapmotor-api (models.py); si en tu Dart
/// difieren, cambia solo la parte derecha de cada linea.
///
/// class _RealSentryClient implements SentryClient {
///   _RealSentryClient(this.api);
///   final LeapmotorClient api; // tu clase
///
///   @override
///   Future<SentrySnapshot> fetchSnapshot(String vin) async {
///     final s = await api.getVehicleStatus(vin); // tu metodo de estado
///     bool? anyDoor;
///     // Si expones puertas individuales, haz el OR aqui; si no, deja null.
///     // anyDoor = (s.doors.frontLeftOpen == true) ||
///     //           (s.doors.frontRightOpen == true) ||
///     //           (s.doors.rearLeftOpen == true) ||
///     //           (s.doors.rearRightOpen == true);
///     final windows = <num?>[
///       // s.windows.leftFrontWindowPercent,
///       // s.windows.rightFrontWindowPercent,
///       // s.windows.leftRearWindowPercent,
///       // s.windows.rightRearWindowPercent,
///     ];
///     return SentrySnapshot(
///       isLocked: s.doors.isLocked,
///       anyDoorOpen: anyDoor,
///       trunkOpen: s.doors.bbcmBackDoorStatus, // porton
///       anyWindowOpen: windows.any((p) => (p ?? 0) > 0)
///           ? true
///           : (windows.every((p) => p == null) ? null : false),
///       readyOn3: s.ignition.bcmKeyPositionOn3, // senal 1258 READY/ON3
///       latitude: s.location.latitude,
///       longitude: s.location.longitude,
///       collectTime: s.collectTime,
///     );
///   }
///
///   @override
///   Future<bool> sendCommand(
///       String vin, int cmdId, Map<String, dynamic> params) async {
///     // Usa tu capa de comandos existente (la misma de lock/find_car).
///     // Si tu shape de parametros binarios difiere de {'value': 0/1},
///     // ajustalo en sentry_engine.dart (sentryParams / recParams).
///     return api.sendRemoteCommand(vin, cmdId, params);
///   }
/// }
EOF

# ----------------------------------------------------------------------------
cat > lib/sentry/sentry_engine.dart << 'EOF'
// sentry_engine.dart - Nucleo del Modo Centinela.
//
// Capa A: centinela nativo del coche (cmd 220) -> vibracion => claxon/luces,
//         corre EN el vehiculo y sobrevive al sueno del TCU (~13 min).
//         OJO: armado remoto en B10 aparcado SIN VERIFICAR aun; probar.
// Capa B: watchdog virtual -> desbloqueo, puertas, porton, ventanillas,
//         encendido READY y movimiento GPS. Detecta en cuanto el TCU
//         despierta (abrir una puerta lo despierta) o mientras este online.
// Grabacion en marcha: dashcam nativa con USB (instrucciones en pantalla) +
//         intento remoto cmd 290 (EXPERIMENTAL, sin confirmar en B10).
//
// Sin estado en memoria: todo via SentryStore => funciona igual desde la UI
// y desde el isolate de WorkManager.

import 'dart:math' as math;

import 'sentry_adapter.dart';
import 'sentry_models.dart';
import 'sentry_notifier.dart';
import 'sentry_store.dart';

// cmd_ids confirmados (leapmotor-api mappings.py)
const int kCmdLock = 110;
const int kCmdFindCar = 120; // claxon + luces
const int kCmdSentry = 220;
const int kCmdVideo = 290; // dashcam/video - EXPERIMENTAL en B10

// Shape de parametros para toggles binarios. Si tu capa de comandos usa otra
// clave (p. ej. {'onOff': 1}), cambia SOLO estas dos funciones.
Map<String, dynamic> sentryParams(bool on) => {'value': on ? 1 : 0};
Map<String, dynamic> recParams(bool on) => {'value': on ? 1 : 0};

class SentryEngine {
  SentryEngine({required this.client, required this.store});

  final SentryClient client;
  final SentryStore store;

  // ---------------- armar / desarmar ----------------

  Future<void> arm(String vin) async {
    final snap = await client.fetchSnapshot(vin);
    await store.saveVin(vin);
    await store.saveBaseline(snap);
    await store.saveLast(snap);
    await store.saveOnline(true);
    await store.saveArmed(true);

    final events = <SentryEvent>[SentryEvent(SentryEventType.armed, 'ARM')];

    final cfg = await store.loadConfig();
    if (cfg.useNative) {
      try {
        final ok = await client.sendCommand(vin, kCmdSentry, sentryParams(true));
        events.add(ok
            ? SentryEvent(SentryEventType.nativeOn, 'NATIVE_ON')
            : SentryEvent(SentryEventType.nativeFailed, 'NATIVE_FAIL'));
      } catch (_) {
        events.add(SentryEvent(SentryEventType.nativeFailed, 'NATIVE_FAIL'));
      }
    }
    await store.appendLog(events);
  }

  Future<void> disarm() async {
    final vin = await store.loadVin();
    await store.saveArmed(false);
    final events = <SentryEvent>[];
    final cfg = await store.loadConfig();
    if (vin != null && cfg.useNative) {
      try {
        final ok =
            await client.sendCommand(vin, kCmdSentry, sentryParams(false));
        if (ok) events.add(SentryEvent(SentryEventType.nativeOff, 'NATIVE_OFF'));
      } catch (_) {}
    }
    events.add(SentryEvent(SentryEventType.disarmed, 'DISARM'));
    await store.appendLog(events);
  }

  // ---------------- ciclo de deteccion ----------------

  /// Un ciclo completo. Llamable desde la UI (Timer) y desde WorkManager.
  Future<void> pollOnce() async {
    if (!await store.loadArmed()) return;
    final vin = await store.loadVin();
    if (vin == null) return;

    final cfg = await store.loadConfig();

    SentrySnapshot snap;
    try {
      snap = await client.fetchSnapshot(vin);
    } catch (_) {
      await _setOnline(false);
      return;
    }

    // Frescura del dato: si el TCU duerme, el backend devuelve datos viejos.
    final stale = snap.collectTime != null &&
        DateTime.now().difference(snap.collectTime!).inMinutes >=
            cfg.freshnessMin;
    await _setOnline(!stale);

    final base = await store.loadBaseline();
    final last = await store.loadLast();
    if (base == null) {
      await store.saveLast(snap);
      return;
    }

    final events = <SentryEvent>[];
    var tamper = false;

    bool rose(bool? prev, bool? cur) =>
        (prev == false || prev == null) && cur == true;

    // Desbloqueo no solicitado (flanco, referenciado a baseline cerrado).
    if (base.isLocked == true &&
        snap.isLocked == false &&
        (last?.isLocked ?? true) == true) {
      events.add(SentryEvent(SentryEventType.unlock, 'UNLOCK',
          lat: snap.latitude, lon: snap.longitude, critical: true));
      tamper = true;
      if (cfg.reassertLock) {
        try {
          await client.sendCommand(vin, kCmdLock, {'value': 1});
        } catch (_) {}
      }
    }

    if (rose(last?.anyDoorOpen, snap.anyDoorOpen)) {
      events.add(SentryEvent(SentryEventType.door, 'DOOR',
          lat: snap.latitude, lon: snap.longitude, critical: true));
      tamper = true;
    }
    if (rose(last?.trunkOpen, snap.trunkOpen)) {
      events.add(SentryEvent(SentryEventType.trunk, 'TRUNK',
          lat: snap.latitude, lon: snap.longitude, critical: true));
      tamper = true;
    }
    if (rose(last?.anyWindowOpen, snap.anyWindowOpen)) {
      events.add(SentryEvent(SentryEventType.window, 'WINDOW',
          lat: snap.latitude, lon: snap.longitude, critical: true));
      tamper = true;
    }

    // Encendido a READY/ON3 estando armado.
    if ((last?.readyOn3 ?? base.readyOn3) != true && snap.readyOn3 == true) {
      events.add(SentryEvent(SentryEventType.wake, 'WAKE',
          lat: snap.latitude, lon: snap.longitude, critical: true));
      tamper = true;
    }

    // Movimiento / remolcado: deriva GPS respecto al punto de armado.
    if (base.hasLocation && snap.hasLocation) {
      final dNow = _haversine(
          base.latitude!, base.longitude!, snap.latitude!, snap.longitude!);
      final dPrev = (last != null && last.hasLocation)
          ? _haversine(
              base.latitude!, base.longitude!, last.latitude!, last.longitude!)
          : 0.0;
      if (dNow > cfg.moveMeters && dPrev <= cfg.moveMeters) {
        events.add(SentryEvent(
            SentryEventType.moved, dNow.toStringAsFixed(0),
            lat: snap.latitude, lon: snap.longitude, critical: true));
        tamper = true;
      }
    }

    // Disuasion: claxon + luces con cooldown.
    if (tamper && cfg.useDeterrent) {
      final lastFire = await store.loadDeterrentAt();
      final okCooldown = lastFire == null ||
          DateTime.now().difference(lastFire).inMinutes >=
              cfg.deterrentCooldownMin;
      if (okCooldown) {
        try {
          final ok = await client.sendCommand(vin, kCmdFindCar, const {});
          if (ok) {
            await store.saveDeterrentAt(DateTime.now());
            events.add(SentryEvent(SentryEventType.deterrent, 'DETERRENT',
                lat: snap.latitude, lon: snap.longitude));
          }
        } catch (_) {}
      }
    }

    await store.saveLast(snap);
    if (events.isNotEmpty) {
      await store.appendLog(events);
      for (final e in events.where((e) => e.critical)) {
        await SentryNotifier.show(
            'Centinela / Sentry', sentryEventText(e, es: true),
            critical: true);
      }
    }
  }

  Future<void> _setOnline(bool online) async {
    final was = await store.loadOnline();
    if (was == online) return;
    await store.saveOnline(online);
    await store.appendLog([
      SentryEvent(
          online ? SentryEventType.online : SentryEventType.offline,
          online ? 'ONLINE' : 'OFFLINE')
    ]);
  }

  // ---------------- grabacion (cmd 290, experimental) ----------------

  Future<bool> setRecording(bool on) async {
    final vin = await store.loadVin();
    if (vin == null) return false;
    try {
      final ok = await client.sendCommand(vin, kCmdVideo, recParams(on));
      await store.appendLog([
        SentryEvent(
            ok
                ? (on ? SentryEventType.recOn : SentryEventType.recOff)
                : SentryEventType.recFailed,
            ok ? (on ? 'REC_ON' : 'REC_OFF') : 'REC_FAIL')
      ]);
      return ok;
    } catch (_) {
      await store
          .appendLog([SentryEvent(SentryEventType.recFailed, 'REC_FAIL')]);
      return false;
    }
  }
}

/// Texto legible de un evento (es/en). Usado por notificaciones y pantalla.
String sentryEventText(SentryEvent e, {required bool es}) {
  switch (e.type) {
    case SentryEventType.armed:
      return es ? 'Centinela activado' : 'Sentry armed';
    case SentryEventType.disarmed:
      return es ? 'Centinela desactivado' : 'Sentry disarmed';
    case SentryEventType.nativeOn:
      return es
          ? 'Centinela del coche (cmd 220) activado'
          : 'On-board sentry (cmd 220) enabled';
    case SentryEventType.nativeOff:
      return es
          ? 'Centinela del coche desactivado'
          : 'On-board sentry disabled';
    case SentryEventType.nativeFailed:
      return es
          ? 'El coche rechazo el cmd 220 (puede requerir vehiculo encendido)'
          : 'Car rejected cmd 220 (may need vehicle powered)';
    case SentryEventType.unlock:
      return es
          ? 'ALERTA: coche desbloqueado estando armado'
          : 'ALERT: vehicle unlocked while armed';
    case SentryEventType.door:
      return es ? 'ALERTA: puerta abierta' : 'ALERT: door opened';
    case SentryEventType.trunk:
      return es ? 'ALERTA: porton abierto' : 'ALERT: trunk opened';
    case SentryEventType.window:
      return es ? 'ALERTA: ventanilla abierta' : 'ALERT: window opened';
    case SentryEventType.moved:
      return es
          ? 'ALERTA: el coche se ha movido ${e.msg} m'
          : 'ALERT: vehicle moved ${e.msg} m';
    case SentryEventType.wake:
      return es
          ? 'ALERTA: el coche se ha encendido (READY)'
          : 'ALERT: vehicle powered up (READY)';
    case SentryEventType.deterrent:
      return es ? 'Claxon y luces activados' : 'Horn and lights triggered';
    case SentryEventType.offline:
      return es
          ? 'Coche dormido (TCU): vigilancia en espera; despierta al manipularlo'
          : 'Vehicle asleep (TCU): watch paused; wakes on tamper';
    case SentryEventType.online:
      return es ? 'Coche en linea de nuevo' : 'Vehicle back online';
    case SentryEventType.recOn:
      return es
          ? 'Grabacion remota enviada (cmd 290)'
          : 'Remote recording sent (cmd 290)';
    case SentryEventType.recOff:
      return es
          ? 'Parada de grabacion enviada (cmd 290)'
          : 'Remote recording stop sent (cmd 290)';
    case SentryEventType.recFailed:
      return es
          ? 'cmd 290 rechazado (experimental, puede no aplicar al B10)'
          : 'cmd 290 rejected (experimental, may not apply to B10)';
  }
}

double _haversine(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _rad(double d) => d * math.pi / 180.0;
EOF

# ----------------------------------------------------------------------------
cat > lib/sentry/sentry_background.dart << 'EOF'
// sentry_background.dart
// AÑADE UNA SOLA LINEA a tu callback de WorkManager existente (~15 min):
//
//   import 'sentry/sentry_background.dart';   // ajusta la ruta
//   ...
//   await sentryBackgroundPoll();
//
// No hace nada si el Centinela no esta armado. Nunca lanza excepciones.

import 'sentry_adapter.dart';
import 'sentry_engine.dart';
import 'sentry_store.dart';

Future<void> sentryBackgroundPoll() async {
  try {
    final store = SentryStore();
    if (!await store.loadArmed()) return;
    final client = await buildSentryClient();
    await SentryEngine(client: client, store: store).pollOnce();
  } catch (_) {
    // silencioso: el siguiente ciclo lo reintenta
  }
}
EOF

# ----------------------------------------------------------------------------
cat > lib/sentry/sentry_screen.dart << 'EOF'
// sentry_screen.dart - Pantalla del Modo Centinela con instrucciones
// integradas (es/en). Activacion en 1 toque.
//
// Integracion desde tu Home (ejemplo):
//   Navigator.push(context, MaterialPageRoute(
//     builder: (_) => SentryScreen(vin: tuVin),
//   ));
//
// Nota: sin `const` en widgets que leen strings localizados (leccion del
// proyecto). Las cadenas van en una clase propia; migra a tus .arb cuando
// quieras.

import 'dart:async';

import 'package:flutter/material.dart';

import 'sentry_adapter.dart';
import 'sentry_engine.dart';
import 'sentry_models.dart';
import 'sentry_store.dart';

class SentryScreen extends StatefulWidget {
  const SentryScreen({super.key, required this.vin});
  final String vin;

  @override
  State<SentryScreen> createState() => _SentryScreenState();
}

class _SentryScreenState extends State<SentryScreen> {
  final _store = SentryStore();
  SentryEngine? _engine;
  String? _adapterError;

  bool _loading = true;
  bool _busy = false;
  bool _armed = false;
  bool _online = true;
  SentryConfig _cfg = const SentryConfig();
  List<SentryEvent> _log = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final client = await buildSentryClient();
      _engine = SentryEngine(client: client, store: _store);
    } catch (e) {
      _adapterError = e.toString();
    }
    await _reload();
    setState(() => _loading = false);
    _restartTimer();
  }

  Future<void> _reload() async {
    _armed = await _store.loadArmed();
    _online = await _store.loadOnline();
    _cfg = await _store.loadConfig();
    _log = await _store.loadLog();
    if (mounted) setState(() {});
  }

  void _restartTimer() {
    _timer?.cancel();
    if (_armed && _engine != null) {
      _timer = Timer.periodic(Duration(seconds: _cfg.pollAwakeSec), (_) async {
        await _engine!.pollOnce();
        await _reload();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _toggleArm() async {
    final eng = _engine;
    if (eng == null) return;
    setState(() => _busy = true);
    try {
      if (_armed) {
        await eng.disarm();
      } else {
        await eng.arm(widget.vin);
      }
      await _reload();
      _restartTimer();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveCfg(SentryConfig c) async {
    _cfg = c;
    await _store.saveConfig(c);
    setState(() {});
    _restartTimer();
  }

  Future<void> _tryRecording(bool on, _S s) async {
    final eng = _engine;
    if (eng == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.recDialogTitle),
        content: Text(s.recDialogBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(s.tryIt)),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    final ok = await eng.setRecording(on);
    await _reload();
    if (mounted) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? s.recAccepted : s.recRejected)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _S.of(context);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(s.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(s.title)),
      body: RefreshIndicator(
        onRefresh: () async {
          if (_engine != null && _armed) await _engine!.pollOnce();
          await _reload();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_adapterError != null) _adapterBanner(s),
            _armCard(s),
            const SizedBox(height: 12),
            _howToCard(s),
            const SizedBox(height: 12),
            _recordingCard(s),
            const SizedBox(height: 12),
            _settingsCard(s),
            const SizedBox(height: 12),
            _logCard(s),
          ],
        ),
      ),
    );
  }

  // ------------------------- tarjetas -------------------------

  Widget _adapterBanner(_S s) => Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(s.adapterMissing,
              style: TextStyle(color: Colors.red.shade900)),
        ),
      );

  Widget _armCard(_S s) {
    final theme = Theme.of(context);
    Color dot;
    String state;
    if (!_armed) {
      dot = theme.disabledColor;
      state = s.standby;
    } else if (_online) {
      dot = Colors.green;
      state = s.watching;
    } else {
      dot = Colors.orange;
      state = s.asleep;
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.circle, size: 12, color: dot),
                const SizedBox(width: 8),
                Expanded(
                    child:
                        Text(state, style: theme.textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed:
                    (_busy || _engine == null) ? null : _toggleArm,
                icon: Icon(_armed ? Icons.shield : Icons.shield_outlined),
                label: Text(
                  _armed ? s.disarmBtn : s.armBtn,
                  style: const TextStyle(fontSize: 18),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _armed ? Colors.red.shade700 : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _howToCard(_S s) => Card(
        child: ExpansionTile(
          leading: const Icon(Icons.help_outline),
          title: Text(s.howTitle),
          subtitle: Text(s.howSubtitle),
          childrenPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            _step('1', s.howStep1),
            _step('2', s.howStep2),
            _step('3', s.howStep3),
            const Divider(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(s.howDetects,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(s.howLimits,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontStyle: FontStyle.italic)),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );

  Widget _recordingCard(_S s) => Card(
        child: ExpansionTile(
          leading: const Icon(Icons.videocam_outlined),
          title: Text(s.recTitle),
          subtitle: Text(s.recSubtitle),
          childrenPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            _step('1', s.recStep1),
            _step('2', s.recStep2),
            _step('3', s.recStep3),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(s.recParkedNote,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontStyle: FontStyle.italic)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (_busy || _engine == null)
                        ? null
                        : () => _tryRecording(true, s),
                    icon: const Icon(Icons.fiber_manual_record,
                        color: Colors.red),
                    label: Text(s.recTryOn),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (_busy || _engine == null)
                        ? null
                        : () => _tryRecording(false, s),
                    icon: const Icon(Icons.stop),
                    label: Text(s.recTryOff),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      );

  Widget _settingsCard(_S s) => Card(
        child: ExpansionTile(
          leading: const Icon(Icons.tune),
          title: Text(s.settings),
          children: [
            SwitchListTile(
              value: _cfg.useNative,
              onChanged: _armed
                  ? null
                  : (v) => _saveCfg(_cfg.copyWith(useNative: v)),
              title: Text(s.cfgNative),
              subtitle: Text(s.cfgNativeHint),
            ),
            SwitchListTile(
              value: _cfg.useDeterrent,
              onChanged: (v) => _saveCfg(_cfg.copyWith(useDeterrent: v)),
              title: Text(s.cfgDeterrent),
              subtitle: Text(s.cfgDeterrentHint),
            ),
            SwitchListTile(
              value: _cfg.reassertLock,
              onChanged: (v) => _saveCfg(_cfg.copyWith(reassertLock: v)),
              title: Text(s.cfgRelock),
              subtitle: Text(s.cfgRelockHint),
            ),
            ListTile(
              title: Text(s.cfgMove),
              subtitle: Slider(
                min: 25,
                max: 250,
                divisions: 9,
                value: _cfg.moveMeters.clamp(25, 250),
                label: '${_cfg.moveMeters.round()} m',
                onChanged: (v) => _saveCfg(_cfg.copyWith(moveMeters: v)),
              ),
              trailing: Text('${_cfg.moveMeters.round()} m'),
            ),
            ListTile(
              title: Text(s.cfgPoll),
              trailing: DropdownButton<int>(
                value: _cfg.pollAwakeSec,
                items: const [15, 30, 60, 120]
                    .map((sec) => DropdownMenuItem<int>(
                          value: sec,
                          child: Text('$sec s'),
                        ))
                    .toList(),
                onChanged: (sec) {
                  if (sec != null) {
                    _saveCfg(_cfg.copyWith(pollAwakeSec: sec));
                  }
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );

  Widget _logCard(_S s) {
    final es = s.es;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(s.log,
                      style: Theme.of(context).textTheme.titleSmall),
                  if (_log.isNotEmpty)
                    TextButton(
                      onPressed: () async {
                        await _store.clearLog();
                        await _reload();
                      },
                      child: Text(s.clear),
                    ),
                ],
              ),
            ),
            if (_log.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(child: Text(s.noEvents)),
              )
            else
              ..._log.map((e) => ListTile(
                    dense: true,
                    leading: Icon(_iconFor(e.type),
                        color: e.critical
                            ? Colors.red
                            : Theme.of(context).hintColor),
                    title: Text(sentryEventText(e, es: es)),
                    subtitle: Text(_fmt(e.at)),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _step(String n, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(radius: 12, child: Text(n)),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
      );

  static IconData _iconFor(SentryEventType t) {
    switch (t) {
      case SentryEventType.armed:
        return Icons.shield;
      case SentryEventType.disarmed:
        return Icons.shield_outlined;
      case SentryEventType.nativeOn:
      case SentryEventType.nativeOff:
        return Icons.sensors;
      case SentryEventType.nativeFailed:
      case SentryEventType.recFailed:
        return Icons.error_outline;
      case SentryEventType.unlock:
        return Icons.lock_open;
      case SentryEventType.door:
        return Icons.sensor_door_outlined;
      case SentryEventType.trunk:
        return Icons.inventory_2_outlined;
      case SentryEventType.window:
        return Icons.window_outlined;
      case SentryEventType.moved:
        return Icons.directions_car;
      case SentryEventType.wake:
        return Icons.power_settings_new;
      case SentryEventType.deterrent:
        return Icons.campaign;
      case SentryEventType.offline:
        return Icons.cloud_off;
      case SentryEventType.online:
        return Icons.cloud_done;
      case SentryEventType.recOn:
      case SentryEventType.recOff:
        return Icons.videocam_outlined;
    }
  }

  static String _fmt(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)}/${two(t.month)} ${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}

// -------------------------- strings es/en --------------------------
class _S {
  final bool es;
  const _S(this.es);
  factory _S.of(BuildContext c) =>
      _S(Localizations.localeOf(c).languageCode == 'es');

  String get title => es ? 'Modo Centinela' : 'Sentry Mode';
  String get standby => es ? 'En espera' : 'Standby';
  String get watching => es ? 'Vigilando el vehiculo' : 'Watching vehicle';
  String get asleep => es
      ? 'Armado - coche dormido (despierta al manipularlo)'
      : 'Armed - vehicle asleep (wakes on tamper)';
  String get armBtn => es ? 'ACTIVAR CENTINELA' : 'ARM SENTRY';
  String get disarmBtn => es ? 'DESACTIVAR' : 'DISARM';

  String get howTitle => es ? 'Como funciona' : 'How it works';
  String get howSubtitle =>
      es ? 'Activacion en 3 pasos' : '3-step activation';
  String get howStep1 =>
      es ? 'Aparca y bloquea el coche.' : 'Park and lock the car.';
  String get howStep2 => es
      ? 'Pulsa ACTIVAR CENTINELA (1 toque).'
      : 'Tap ARM SENTRY (one tap).';
  String get howStep3 => es
      ? 'Listo. Recibiras una alerta si el coche se desbloquea, se abre, se enciende o se mueve.'
      : 'Done. You will get an alert if the car unlocks, opens, powers up or moves.';
  String get howDetects => es
      ? 'Vigila: desbloqueo no solicitado, puertas, porton, ventanillas, encendido (READY) y movimiento/remolcado por GPS. Ademas arma el centinela del propio coche (vibracion -> claxon y luces), que funciona aunque el coche duerma.'
      : 'Watches: uncommanded unlock, doors, trunk, windows, power-up (READY) and GPS move/tow. Also arms the car\'s own sentry (shake -> horn and lights), which works even while the car sleeps.';
  String get howLimits => es
      ? 'Limite conocido: el firmware europeo no permite grabar video aparcado, y el coche duerme ~13 min tras bloquear; parte de los avisos llegan cuando el coche despierta al ser manipulado.'
      : 'Known limit: EU firmware disables parked video recording, and the car sleeps ~13 min after locking; some alerts arrive when tampering wakes the car.';

  String get recTitle =>
      es ? 'Grabacion en marcha (dashcam)' : 'Drive recording (dashcam)';
  String get recSubtitle => es
      ? 'Camaras del coche grabando al conducir'
      : 'On-board cameras recording while driving';
  String get recStep1 => es
      ? 'Formatea un USB en FAT32 (64 GB recomendado).'
      : 'Format a USB stick as FAT32 (64 GB recommended).';
  String get recStep2 => es
      ? 'Insertalo en el puerto USB "REC" bajo el reposabrazos.'
      : 'Insert it in the "REC" USB port under the armrest.';
  String get recStep3 => es
      ? 'Al conducir, el coche graba solo, en bloques de 3 min (camaras frontal, trasera y laterales).'
      : 'While driving, the car records automatically in 3-min blocks (front, rear and side cameras).';
  String get recParkedNote => es
      ? 'Aparcado no graba: esta desactivado en el firmware UE actual. Si una OTA lo habilita, esta pantalla lo aprovechara sin cambios.'
      : 'No parked recording: disabled in current EU firmware. If an OTA enables it, this screen will benefit without changes.';
  String get recTryOn =>
      es ? 'Grabar (cmd 290 - exp.)' : 'Record (cmd 290 - exp.)';
  String get recTryOff => es ? 'Parar (exp.)' : 'Stop (exp.)';
  String get recDialogTitle =>
      es ? 'Comando experimental' : 'Experimental command';
  String get recDialogBody => es
      ? 'cmd 290 (video/dashcam) no esta confirmado en el B10. Es seguro probarlo: si el coche no lo soporta, simplemente lo rechaza.'
      : 'cmd 290 (video/dashcam) is unconfirmed on the B10. Safe to try: if unsupported, the car just rejects it.';
  String get tryIt => es ? 'Probar' : 'Try';
  String get cancel => es ? 'Cancelar' : 'Cancel';
  String get recAccepted => es
      ? 'Comando aceptado por el backend'
      : 'Command accepted by backend';
  String get recRejected =>
      es ? 'Comando rechazado' : 'Command rejected';

  String get settings => es ? 'Ajustes' : 'Settings';
  String get cfgNative =>
      es ? 'Centinela del coche (cmd 220)' : 'On-board sentry (cmd 220)';
  String get cfgNativeHint => es
      ? 'Deteccion de vibracion del propio vehiculo al armar.'
      : 'Vehicle shake detection armed with sentry.';
  String get cfgDeterrent =>
      es ? 'Disuasion: claxon + luces' : 'Deterrent: horn + lights';
  String get cfgDeterrentHint => es
      ? 'Se dispara al detectar manipulacion real.'
      : 'Fires on a detected tamper.';
  String get cfgRelock =>
      es ? 'Rebloquear si se desbloquea' : 'Re-lock on unlock';
  String get cfgRelockHint => es
      ? 'Reenvia el cierre si detecta un desbloqueo no solicitado.'
      : 'Re-sends lock on an uncommanded unlock.';
  String get cfgMove =>
      es ? 'Sensibilidad de movimiento' : 'Move sensitivity';
  String get cfgPoll =>
      es ? 'Sondeo con la app abierta' : 'Poll with app open';

  String get log => es ? 'Registro de eventos' : 'Event log';
  String get noEvents => es ? 'Sin eventos todavia' : 'No events yet';
  String get clear => es ? 'Borrar' : 'Clear';
  String get adapterMissing => es
      ? 'Adaptador sin conectar: edita lib/sentry/sentry_adapter.dart (bloques 1-3) y recompila.'
      : 'Adapter not wired: edit lib/sentry/sentry_adapter.dart (blocks 1-3) and rebuild.';
}
EOF

# ----------------------------------------------------------------------------
cat << 'DONE'
============================================================
MODULO CENTINELA CREADO en lib/sentry/
============================================================
PASOS RESTANTES (los unicos):

1) ADAPTADOR (obligatorio, ~10 lineas):
   lib/sentry/sentry_adapter.dart -> bloques (1)(2)(3):
   import de tu cliente, factoria, y mapeo VehicleStatus->SentrySnapshot
   (plantilla comentada incluida con los nombres del port de leapmotor-api).

2) WORKMANAGER (1 linea) en tu callback existente:
   import 'sentry/sentry_background.dart';
   await sentryBackgroundPoll();

3) RUTA desde tu Home:
   Navigator.push(context, MaterialPageRoute(
     builder: (_) => SentryScreen(vin: tuVin)));

4) pubspec.yaml: comprueba que existen (ya deberias tenerlas):
   shared_preferences, flutter_local_notifications

NOTAS:
- Shape de toggles binarios asumido {'value': 0/1}; si tu capa usa otra
  clave, cambia solo sentryParams()/recParams() en sentry_engine.dart.
- cmd 220 remoto en B10 aparcado: SIN VERIFICAR -> primera prueba con el
  coche a la vista. cmd 290: experimental, boton con aviso en pantalla.
- Ya tienes notificacion de "unexpected unlock" en la app: valora
  desactivarla cuando el Centinela este armado para no duplicar avisos.
- flutter gen-l10n no es necesario: strings es/en autocontenidas.
Compila: flutter build apk --release
============================================================
DONE
