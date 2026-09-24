// Telemetria saliente (clon de la integracion MQTT de LeapMotor Mate):
// publica cada lectura del coche en el broker MQTT del usuario y/o en un
// webhook HTTPS propio (Home Assistant, Node-RED, un script...).
//
// Todo es opt-in: con ambos interruptores apagados la app no envia nada a
// ningun sitio (como siempre). Los envios van limitados a uno por minuto y
// cualquier fallo se traga: la telemetria NUNCA debe romper el refresco
// del coche.

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

/// Configuracion de la telemetria saliente.
class ConfigTelemetria {
  final bool mqttOn;
  final String host;
  final int port;
  final String user;
  final String pass;
  final String topic;
  final bool tls;
  final bool hookOn;
  final String hookUrl;

  const ConfigTelemetria({
    this.mqttOn = false,
    this.host = '',
    this.port = 1883,
    this.user = '',
    this.pass = '',
    this.topic = 'lmb10/coche',
    this.tls = false,
    this.hookOn = false,
    this.hookUrl = '',
  });

  Map<String, dynamic> toJson() => {
        'mqttOn': mqttOn,
        'host': host,
        'port': port,
        'user': user,
        'pass': pass,
        'topic': topic,
        'tls': tls,
        'hookOn': hookOn,
        'hookUrl': hookUrl,
      };

  factory ConfigTelemetria.fromJson(Map<String, dynamic> m) => ConfigTelemetria(
        mqttOn: m['mqttOn'] == true,
        host: (m['host'] as String?) ?? '',
        port: (m['port'] as num?)?.toInt() ?? 1883,
        user: (m['user'] as String?) ?? '',
        pass: (m['pass'] as String?) ?? '',
        topic: ((m['topic'] as String?)?.isNotEmpty ?? false)
            ? m['topic'] as String
            : 'lmb10/coche',
        tls: m['tls'] == true,
        hookOn: m['hookOn'] == true,
        hookUrl: (m['hookUrl'] as String?) ?? '',
      );
}

class TelemetryPush {
  static const _k = 'lm_telemetry_push_v1';
  static const _storage = FlutterSecureStorage();

  /// Minimo entre envios (cada pollero del coche no debe reventar el broker).
  static const int kMinIntervaloMs = 60000;

  static int _ultimoEnvioMs = 0;
  static MqttServerClient? _client;
  static String _clienteHuella = '';

  static Future<ConfigTelemetria> cargar() async {
    try {
      final raw = await _storage.read(key: _k);
      if (raw != null) {
        return ConfigTelemetria.fromJson(
            Map<String, dynamic>.from(json.decode(raw) as Map));
      }
    } catch (_) {}
    return const ConfigTelemetria();
  }

  static Future<void> guardar(ConfigTelemetria c) async {
    try {
      await _storage.write(key: _k, value: json.encode(c.toJson()));
    } catch (_) {}
    // Si cambio la config, la conexion vieja ya no vale.
    _desconectar();
  }

  /// Cuerpo JSON del envio (el mismo para MQTT y webhook). Puro y testable.
  static Map<String, dynamic> payload({
    required int ts,
    required double soc,
    int? km,
    double? v,
    double? a,
    double? tBat,
    double? tExt,
    double? lat,
    double? lon,
    bool? cargando,
  }) {
    final m = <String, dynamic>{'ts': ts, 'soc': soc};
    if (km != null) m['km'] = km;
    if (v != null) m['voltios'] = v;
    if (a != null) m['amperios'] = a;
    if (tBat != null) m['temp_bateria'] = tBat;
    if (tExt != null) m['temp_exterior'] = tExt;
    if (lat != null && lon != null) {
      m['lat'] = lat;
      m['lon'] = lon;
    }
    if (cargando != null) m['cargando'] = cargando;
    return m;
  }

  static void _desconectar() {
    try {
      _client?.disconnect();
    } catch (_) {}
    _client = null;
    _clienteHuella = '';
  }

  static Future<void> _publicaMqtt(ConfigTelemetria c, String cuerpo) async {
    final huella = '${c.host}:${c.port}:${c.user}:${c.tls}';
    if (_client == null || _clienteHuella != huella) {
      _desconectar();
      final clientId =
          'lmb10-${DateTime.now().millisecondsSinceEpoch % 1000000}';
      final cli = MqttServerClient.withPort(c.host, clientId, c.port);
      cli.secure = c.tls;
      cli.logging(on: false);
      cli.keepAlivePeriod = 30;
      cli.connectTimeoutPeriod = 8000;
      var msg = MqttConnectMessage().withClientIdentifier(clientId).startClean();
      if (c.user.isNotEmpty) msg = msg.authenticateAs(c.user, c.pass);
      cli.connectionMessage = msg;
      cli.onDisconnected = () {};
      await cli.connect().timeout(const Duration(seconds: 10));
      if (cli.connectionStatus?.state != MqttConnectionState.connected) {
        cli.disconnect();
        return;
      }
      _client = cli;
      _clienteHuella = huella;
    }
    final cli = _client;
    if (cli == null ||
        cli.connectionStatus?.state != MqttConnectionState.connected) {
      _desconectar();
      return;
    }
    final b = MqttClientPayloadBuilder()..addString(cuerpo);
    cli.publishMessage(c.topic, MqttQos.atLeastOnce, b.payload!);
  }

  /// Envia una lectura a los destinos activos (MQTT y/o webhook). Nunca
  /// lanza; llamar sin await (fire-and-forget).
  static Future<void> enviar({
    required double soc,
    int? km,
    double? v,
    double? a,
    double? tBat,
    double? tExt,
    double? lat,
    double? lon,
    bool? cargando,
  }) async {
    try {
      final c = await cargar();
      if (!c.mqttOn && !c.hookOn) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _ultimoEnvioMs < kMinIntervaloMs) return;
      _ultimoEnvioMs = now;
      final cuerpo = json.encode(payload(
          ts: now,
          soc: soc,
          km: km,
          v: v,
          a: a,
          tBat: tBat,
          tExt: tExt,
          lat: lat,
          lon: lon,
          cargando: cargando));
      if (c.mqttOn && c.host.isNotEmpty) {
        try {
          await _publicaMqtt(c, cuerpo);
        } catch (_) {
          _desconectar();
        }
      }
      if (c.hookOn && c.hookUrl.startsWith('http')) {
        try {
          await http
              .post(Uri.parse(c.hookUrl),
                  headers: {'Content-Type': 'application/json'}, body: cuerpo)
              .timeout(const Duration(seconds: 8));
        } catch (_) {}
      }
    } catch (_) {}
  }
}
