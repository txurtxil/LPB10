// notif_settings.dart — Ajustes de notificaciones (v3.60.204, peticion de
// betatester): cada tipo de aviso de la app se puede apagar por separado.
// Por defecto todos activos (el comportamiento actual no cambia).
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage();

class NotifKey {
  static const bateriaBaja = 'lm_notif_batbaja_v1';
  static const cargaCompleta = 'lm_notif_carga_v1';
  static const desbloqueo = 'lm_notif_unlock_v1';
  static const abierto = 'lm_notif_open_v1';
  static const llegadaCasa = 'lm_notif_home_v1';
  static const pvpc = 'lm_notif_pvpc_v1';
  static const informe = 'lm_notif_informe_v1';
}

Future<bool> _lee(String k) async => (await _storage.read(key: k)) != '0';
Future<void> _guarda(String k, bool v) =>
    _storage.write(key: k, value: v ? '1' : '0');

Future<bool> notifBateriaBaja() => _lee(NotifKey.bateriaBaja);
Future<void> setNotifBateriaBaja(bool v) => _guarda(NotifKey.bateriaBaja, v);
Future<bool> notifCargaCompleta() => _lee(NotifKey.cargaCompleta);
Future<void> setNotifCargaCompleta(bool v) => _guarda(NotifKey.cargaCompleta, v);
Future<bool> notifDesbloqueo() => _lee(NotifKey.desbloqueo);
Future<void> setNotifDesbloqueo(bool v) => _guarda(NotifKey.desbloqueo, v);
Future<bool> notifAbierto() => _lee(NotifKey.abierto);
Future<void> setNotifAbierto(bool v) => _guarda(NotifKey.abierto, v);
Future<bool> notifLlegadaCasa() => _lee(NotifKey.llegadaCasa);
Future<void> setNotifLlegadaCasa(bool v) => _guarda(NotifKey.llegadaCasa, v);
Future<bool> notifPvpc() => _lee(NotifKey.pvpc);
Future<void> setNotifPvpc(bool v) => _guarda(NotifKey.pvpc, v);
Future<bool> notifInforme() => _lee(NotifKey.informe);
Future<void> setNotifInforme(bool v) => _guarda(NotifKey.informe, v);
