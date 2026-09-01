// Copia de seguridad a Google Drive del usuario.
//
// google_sign_in 7.x cambio la API por completo respecto a versiones
// anteriores: GoogleSignIn es ahora un singleton (GoogleSignIn.instance),
// exige initialize() antes de cualquier otra llamada, y separa AUTENTICAR
// (saber quien es el usuario) de AUTORIZAR (darle a la app permiso sobre
// Drive) en dos pasos distintos.
//
// NO se usa el paquete googleapis (pesado, tipos para decenas de servicios
// que no usamos): se habla con la API REST de Drive v3 directamente por
// http, que ya esta en el proyecto.
//
// Scope drive.file: solo da acceso a los ficheros que ESTA app crea, nunca
// al resto del Drive del usuario. Por eso no requiere verificacion de
// Google.

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'backup_helper.dart';
import 'car_log_bridge.dart';

class DriveBackup {
  static const _scopes = ['https://www.googleapis.com/auth/drive.file'];
  static const _prefs = FlutterSecureStorage();
  static const _kAutomatico = 'lm_drive_auto_v1';
  static const _kLastAuto = 'lm_drive_last_auto_ms';

  static const _carpetaNombre = 'LMB10 backups';
  static const _maxCopias = 6;

  static bool _inicializado = false;
  static GoogleSignInAccount? _cuenta;

  static GoogleSignInAccount? get cuentaActual => _cuenta;

  static Future<bool> automaticoActivo() async =>
      (await _prefs.read(key: _kAutomatico)) == '1';

  static Future<void> setAutomatico(bool v) =>
      _prefs.write(key: _kAutomatico, value: v ? '1' : '0');

  /// Sube una copia si el automatico esta activo, hay sesion y ha pasado al
  /// menos un dia desde la ultima subida automatica. Nunca lanza excepcion:
  /// colgado del refresco de fondo, un fallo aqui no puede tumbar nada mas.
  static Future<void> autoBackupIfDue() async {
    try {
      if (!await automaticoActivo()) return;
      // Comprobar primero si toca backup, ANTES de intentar conectar con
      // Google: evita el prompt de cuenta en cada apertura de la app cuando
      // el backup de hoy ya se hizo.
      final lastRaw = await _prefs.read(key: _kLastAuto);
      final last = int.tryParse(lastRaw ?? '') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - last < 24 * 3600 * 1000) return;
      final cuenta = _cuenta ?? await conectarSilencioso();
      if (cuenta == null) return;
      final ok = await subirAhora();
      if (ok) await _prefs.write(key: _kLastAuto, value: now.toString());
    } catch (e) {
      await CarLogBridge.log('Drive auto excepcion: ' + e.toString());
    }
  }

  static Future<void> _asegurarInit() async {
    if (_inicializado) return;
    await GoogleSignIn.instance.initialize(
      serverClientId:
          '457622951832-gp7co9k1j0rs7qku77cf0v4e7gpuagrt.apps.googleusercontent.com',
    );
    _inicializado = true;
  }

  static Future<GoogleSignInAccount?> conectar() async {
    try {
      await _asegurarInit();
      final cuenta = await GoogleSignIn.instance.authenticate();
      _cuenta = cuenta;
      return cuenta;
    } catch (e) {
      await CarLogBridge.log('Drive login excepcion: ' + e.toString());
      return null;
    }
  }

  static Future<GoogleSignInAccount?> conectarSilencioso() async {
    try {
      await _asegurarInit();
      final cuenta =
          await GoogleSignIn.instance.attemptLightweightAuthentication();
      _cuenta = cuenta;
      if (cuenta == null) {
        // Sin excepcion pero tampoco cuenta: no habia sesion previa que
        // reconectar en silencio. Distinto de una excepcion real (ver el
        // catch de abajo), que apuntaria a un fallo de la libreria/plataforma
        // en vez de "simplemente no habia con que conectar".
        await CarLogBridge.log('Drive conectarSilencioso: sin cuenta (null), sin excepcion');
      }
      return cuenta;
    } catch (e) {
      await CarLogBridge.log('Drive conectarSilencioso excepcion: ' + e.toString());
      return null;
    }
  }

  static Future<void> desconectar() async {
    await _asegurarInit();
    await GoogleSignIn.instance.signOut();
    _cuenta = null;
  }

  /// Autoriza el scope de Drive para la cuenta, pidiendolo si hace falta.
  /// Paso NUEVO en v7: antes iba junto al login, ahora es explicito.
  static Future<String?> _tokenDrive(GoogleSignInAccount cuenta) async {
    final existente =
        await cuenta.authorizationClient.authorizationForScopes(_scopes);
    if (existente != null) return existente.accessToken;
    final pedido =
        await cuenta.authorizationClient.authorizeScopes(_scopes);
    return pedido.accessToken;
  }

  static Future<Map<String, String>?> _headers() async {
    final cuenta = _cuenta ?? await conectarSilencioso();
    if (cuenta == null) return null;
    final token = await _tokenDrive(cuenta);
    if (token == null) return null;
    return {'Authorization': 'Bearer ' + token};
  }

  static Future<String?> _carpetaId(Map<String, String> headers) async {
    final q = Uri.encodeComponent(
        "name='$_carpetaNombre' and mimeType='application/vnd.google-apps.folder' and trashed=false");
    final r = await http.get(
      Uri.parse(
          'https://www.googleapis.com/drive/v3/files?q=$q&fields=files(id)'),
      headers: headers,
    );
    if (r.statusCode != 200) return null;
    final j = json.decode(r.body) as Map<String, dynamic>;
    final files = j['files'] as List?;
    if (files != null && files.isNotEmpty) return files.first['id'] as String;

    final rc = await http.post(
      Uri.parse('https://www.googleapis.com/drive/v3/files'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: json.encode({
        'name': _carpetaNombre,
        'mimeType': 'application/vnd.google-apps.folder',
      }),
    );
    if (rc.statusCode != 200) return null;
    return (json.decode(rc.body) as Map<String, dynamic>)['id'] as String?;
  }

  static Future<bool> subirAhora() async {
    try {
      final headers = await _headers();
      if (headers == null) {
        await CarLogBridge.log('Drive: sin sesion, no se sube');
        return false;
      }
      final folderId = await _carpetaId(headers);
      if (folderId == null) {
        await CarLogBridge.log('Drive: no se pudo crear/encontrar carpeta');
        return false;
      }

      final datos = await BackupHelper.contenidoParaSubir();
      final ahora = DateTime.now();
      final nombre = 'lmb10_backup_' +
          ahora.toIso8601String().substring(0, 16).replaceAll(':', '-') +
          '.json';

      final meta = json.encode({
        'name': nombre,
        'parents': [folderId]
      });
      final boundary =
          'lmb10_boundary_' + ahora.millisecondsSinceEpoch.toString();
      final body = '--$boundary\r\n'
          'Content-Type: application/json; charset=UTF-8\r\n\r\n'
          '$meta\r\n'
          '--$boundary\r\n'
          'Content-Type: application/json\r\n\r\n'
          '$datos\r\n'
          '--$boundary--';

      final r = await http.post(
        Uri.parse(
            'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart'),
        headers: {
          ...headers,
          'Content-Type': 'multipart/related; boundary=$boundary',
        },
        body: body,
      );

      if (r.statusCode != 200) {
        await CarLogBridge.log(
            'Drive HTTP ' + r.statusCode.toString() + ': ' + r.body);
        return false;
      }
      await CarLogBridge.log('Drive: backup subido ' + nombre);
      await _rotar(headers, folderId);
      return true;
    } catch (e) {
      await CarLogBridge.log('Drive excepcion: ' + e.toString());
      return false;
    }
  }

  static Future<void> _rotar(
      Map<String, String> headers, String folderId) async {
    try {
      final q = Uri.encodeComponent("'$folderId' in parents and trashed=false");
      final r = await http.get(
        Uri.parse(
            'https://www.googleapis.com/drive/v3/files?q=$q&orderBy=createdTime&fields=files(id,name)'),
        headers: headers,
      );
      if (r.statusCode != 200) return;
      final files =
          ((json.decode(r.body) as Map<String, dynamic>)['files'] as List?) ??
              [];
      if (files.length <= _maxCopias) return;
      final sobran = files.length - _maxCopias;
      for (var i = 0; i < sobran; i++) {
        await http.delete(
          Uri.parse(
              'https://www.googleapis.com/drive/v3/files/${files[i]['id']}'),
          headers: headers,
        );
      }
      await CarLogBridge.log(
          'Drive: rotadas ' + sobran.toString() + ' copias antiguas');
    } catch (e) {
      await CarLogBridge.log('Drive rotacion excepcion: ' + e.toString());
    }
  }
}
