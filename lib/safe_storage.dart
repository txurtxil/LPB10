import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wrapper seguro para FlutterSecureStorage.
///
/// Problema #33: en algunos dispositivos (Xiaomi/Samsung con Keystore roto
/// tras actualizaciones) las llamadas a FlutterSecureStorage pueden colgar
/// indefinidamente. Si eso ocurre en el arranque, la app queda inutilizable.
///
/// Este helper:
/// - Aplica un timeout duro (por defecto 3 s).
/// - Para datos NO secretos ofrece fallback automático a SharedPreferences.
/// - Nunca lanza; devuelve null en caso de fallo o timeout.
class SafeStorage {
  static const _secure = FlutterSecureStorage();
  static const Duration defaultTimeout = Duration(seconds: 3);

  /// Lectura con timeout. Devuelve null si timeout o error.
  static Future<String?> readSecure(
    String key, {
    Duration timeout = defaultTimeout,
  }) async {
    try {
      return await _secure.read(key: key).timeout(timeout);
    } catch (_) {
      return null;
    }
  }

  /// Escritura con timeout. Silenciosa si falla.
  static Future<void> writeSecure(
    String key,
    String? value, {
    Duration timeout = defaultTimeout,
  }) async {
    try {
      if (value == null) {
        await _secure.delete(key: key).timeout(timeout);
      } else {
        await _secure.write(key: key, value: value).timeout(timeout);
      }
    } catch (_) {}
  }

  /// Lectura de flag no secreto con fallback a SharedPreferences.
  static Future<String?> readNonSecret(
    String key, {
    Duration timeout = defaultTimeout,
  }) async {
    final fromSecure = await readSecure(key, timeout: timeout);
    if (fromSecure != null) return fromSecure;

    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } catch (_) {
      return null;
    }
  }

  /// Escritura de flag no secreto en AMBOS sitios (migración suave).
  static Future<void> writeNonSecret(String key, String? value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value == null) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, value);
      }
    } catch (_) {}

    await writeSecure(key, value);
  }
}
