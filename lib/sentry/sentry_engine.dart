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
