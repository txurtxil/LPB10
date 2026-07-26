// sentry_adapter.dart - Adaptador REAL sobre LeapmotorApiClient (v1.1).
// Cableado automatico: sesion desde flutter_secure_storage (lm_session_v1),
// PIN desde lm_pin_v1 (o inyectado desde la pantalla), getVehicleList()
// obligatorio antes de getVehicleStatus().

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../leapmotor_engine.dart';
import 'sentry_models.dart';

const _storage = FlutterSecureStorage();
const _kSessionKey = 'lm_session_v1';
const _kPinKey = 'lm_pin_v1';

abstract class SentryClient {
  Future<SentrySnapshot> fetchSnapshot(String vin);

  /// true si el backend acepta y confirma el comando.
  Future<bool> sendCommand(String vin, int cmdId, Map<String, dynamic> params);
}

/// Crea el cliente del Centinela restaurando la sesion guardada de la app.
/// [pin]: si se pasa (pantalla), se usa; si no (WorkManager), se lee el PIN
/// recordado (lm_pin_v1). Sin PIN, la vigilancia funciona igual pero los
/// comandos (220/110/120/290) devuelven false.
Future<SentryClient> buildSentryClient({String? pin}) async {
  final raw = await _storage.read(key: _kSessionKey);
  if (raw == null) {
    throw StateError('Sin sesion guardada: inicia sesion en la app primero.');
  }
  final session =
      SessionData.fromMap(Map<String, String>.from(json.decode(raw) as Map));
  final staticClient = await createStaticClient();
  final api = LeapmotorApiClient(staticClient);
  await api.restoreSession(session);
  await api.getVehicleList(); // getVehicleStatus busca el VIN en esta lista
  final effectivePin = pin ?? await _storage.read(key: _kPinKey) ?? '';
  return _RealSentryClient(api, effectivePin);
}

class _RealSentryClient implements SentryClient {
  _RealSentryClient(this.api, this.pin);

  final LeapmotorApiClient api;
  final String pin;

  @override
  Future<SentrySnapshot> fetchSnapshot(String vin) async {
    final s = await api.getVehicleStatus(vin);
    final raw = s.raw;

    // Puertas individuales (senales 1277-1280, mezcladas en raw por
    // mergeSignalToNamed). Semantica asumida: 1 = abierta. Si estuviera
    // invertida, el detector de flancos simplemente no saltaria (sin falsas
    // alarmas); verificar con la pantalla de debug (snapshot/diff).
    final doors = <bool?>[
      _asBoolRaw(raw['lbcmDriverDoorStatus']),
      _asBoolRaw(raw['rbcmDriverDoorStatus']),
      _asBoolRaw(raw['lbcmLeftRearDoorStatus']),
      _asBoolRaw(raw['rbcmRightRearDoorStatus']),
    ];
    final bool? anyDoor = doors.every((d) => d == null)
        ? null
        : doors.any((d) => d == true);

    return SentrySnapshot(
      isLocked: s.driverDoorLockStatus,
      anyDoorOpen: anyDoor,
      trunkOpen: s.bbcmBackDoorStatus,
      // El estado del vehiculo no expone posicion de ventanillas: null
      // desactiva limpiamente ese detector.
      anyWindowOpen: null,
      readyOn3: _asBoolRaw(raw['bcmKeyPositionOn3']), // senal 1258
      latitude: s.latitude,
      longitude: s.longitude,
      collectTime: _collectTime(raw),
    );
  }

  @override
  Future<bool> sendCommand(
      String vin, int cmdId, Map<String, dynamic> params) async {
    if (pin.isEmpty) return false; // sin PIN no hay comandos remotos
    final on = params['value'] == 1;
    try {
      switch (cmdId) {
        case 220:
          if (on) {
            await api.sentryModeOn(vin, pin);
          } else {
            await api.sentryModeOff(vin, pin);
          }
          return true;
        case 110:
          await api.lockVehicle(vin, pin);
          return true;
        case 120:
          await api.findVehicle(vin, pin);
          return true;
        case 290:
          // Experimental: operacion 'open'/'close' por simetria con el
          // patron {"operation": ...} de unlockCharger. Sin confirmar en B10.
          await api.videoCommand(vin, pin, on ? 'open' : 'close');
          return true;
        default:
          return false;
      }
    } on LeapmotorApiException {
      return false;
    } catch (_) {
      return false;
    }
  }
}

bool? _asBoolRaw(dynamic v) {
  if (v == null) return null;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v.toString().toLowerCase();
  if (s == '1' || s == 'true') return true;
  if (s == '0' || s == 'false') return false;
  return null;
}

DateTime? _collectTime(Map<String, dynamic> raw) {
  for (final k in ['collectTime', 'collect_time', 'reportTime', 'uploadTime']) {
    final v = raw[k];
    if (v == null) continue;
    if (v is num) {
      final n = v.toInt();
      if (n > 100000000000) return DateTime.fromMillisecondsSinceEpoch(n);
      if (n > 100000000) return DateTime.fromMillisecondsSinceEpoch(n * 1000);
      continue;
    }
    final s = v.toString();
    final asInt = int.tryParse(s);
    if (asInt != null) {
      if (asInt > 100000000000) {
        return DateTime.fromMillisecondsSinceEpoch(asInt);
      }
      if (asInt > 100000000) {
        return DateTime.fromMillisecondsSinceEpoch(asInt * 1000);
      }
      continue;
    }
    final dt = DateTime.tryParse(s);
    if (dt != null) return dt;
  }
  return null;
}
