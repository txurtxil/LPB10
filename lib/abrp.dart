// Integracion con A Better Route Planner (ABRP).
//
// La API de telemetria de ABRP usa claves PERSONALES, no de aplicacion: cada
// clave es de una cuenta de Iternio concreta, con limite de 2 peticiones por
// segundo. No hay clave de aplicacion que se pueda distribuir en el codigo:
// eso exigiria el flujo OAuth2 completo, que necesita un client_secret
// propio, y este proyecto es de codigo abierto con un repo publico. Por eso
// cada usuario crea la suya en abetterrouteplanner.com/home/app/api-keys
// y su token de vehiculo desde "Live data" en el coche dentro de ABRP.
//
// Referencia: https://documenter.getpostman.com/view/7396339/SWTK5a8w

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const _abrpStore = FlutterSecureStorage();
const _kApiKey = 'lm_abrp_apikey_v1';
const _kToken = 'lm_abrp_token_v1';
const _kActivo = 'lm_abrp_activo_v1';

class Abrp {
  static Future<String> apiKey() async =>
      (await _abrpStore.read(key: _kApiKey))?.trim() ?? '';

  static Future<String> token() async =>
      (await _abrpStore.read(key: _kToken))?.trim() ?? '';

  static Future<bool> activo() async =>
      (await _abrpStore.read(key: _kActivo)) == '1';

  static Future<void> guardar({
    required String apiKey,
    required String token,
    required bool activo,
  }) async {
    await _abrpStore.write(key: _kApiKey, value: apiKey.trim());
    await _abrpStore.write(key: _kToken, value: token.trim());
    await _abrpStore.write(key: _kActivo, value: activo ? '1' : '0');
  }

  /// Manda un punto de telemetria. Solo si esta activo y hay clave+token.
  ///
  /// No lanza excepcion nunca: un fallo aqui no debe afectar al resto del
  /// refresco de la app. Devuelve true si se envio.
  static Future<bool> enviarTelemetria({
    required double? soc,
    required double? lat,
    required double? lon,
    required int? odometroKm,
    required bool cargando,
    required double? potenciaKw,
    required double? tempExtC,
  }) async {
    try {
      if (!await activo()) return false;
      final k = await apiKey();
      final t = await token();
      if (k.isEmpty || t.isEmpty) return false;
      if (soc == null) return false;

      final tlm = <String, dynamic>{
        'utc': DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
        'soc': soc,
        'is_charging': cargando ? 1 : 0,
      };
      if (lat != null && lon != null) {
        tlm['lat'] = lat;
        tlm['lon'] = lon;
      }
      if (odometroKm != null) tlm['odometer'] = odometroKm;
      if (potenciaKw != null) {
        // ABRP usa power en kW, positivo consumiendo, negativo cargando.
        tlm['power'] = cargando ? -potenciaKw.abs() : potenciaKw;
      }
      if (tempExtC != null) tlm['ext_temp'] = tempExtC;

      final uri = Uri.parse('https://api.iternio.com/1/tlm/send').replace(
        queryParameters: {
          'api_key': k,
          'token': t,
          'tlm': json.encode(tlm),
        },
      );
      final r = await http.get(uri).timeout(const Duration(seconds: 10));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Enlace profundo para abrir ABRP con el SoC actual precargado. No
  /// necesita clave ni token: es solo una URL.
  static String deepLink({
    required double soc,
    double? lat,
    double? lon,
  }) {
    final params = <String, String>{'soc': soc.round().toString()};
    if (lat != null && lon != null) {
      params['lat'] = lat.toStringAsFixed(5);
      params['lon'] = lon.toStringAsFixed(5);
    }
    final qs = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    return 'https://abetterrouteplanner.com/?$qs';
  }
}
