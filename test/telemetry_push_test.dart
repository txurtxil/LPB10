// Tests de la telemetria saliente (MQTT/webhook): cuerpo JSON y
// serializacion de la configuracion.
import 'package:flutter_test/flutter_test.dart';
import 'package:lmb10/telemetry_push.dart';

void main() {
  group('TelemetryPush.payload', () {
    test('lectura completa lleva todos los campos', () {
      final p = TelemetryPush.payload(
          ts: 1000, soc: 62.5, km: 12345, v: 398.2, a: -12.4,
          tBat: 21, tExt: 15.5, lat: 43.38, lon: -1.79, cargando: true);
      expect(p['ts'], 1000);
      expect(p['soc'], 62.5);
      expect(p['km'], 12345);
      expect(p['voltios'], 398.2);
      expect(p['amperios'], -12.4);
      expect(p['temp_bateria'], 21);
      expect(p['temp_exterior'], 15.5);
      expect(p['lat'], 43.38);
      expect(p['lon'], -1.79);
      expect(p['cargando'], true);
    });

    test('los null se omiten (lectura sin telemetria ni posicion)', () {
      final p = TelemetryPush.payload(ts: 1000, soc: 62.5);
      expect(p.keys, ['ts', 'soc']);
    });

    test('lat sin lon no publica posicion a medias', () {
      final p = TelemetryPush.payload(ts: 1000, soc: 50, lat: 43.38);
      expect(p.containsKey('lat'), isFalse);
      expect(p.containsKey('lon'), isFalse);
    });
  });

  group('ConfigTelemetria', () {
    test('valores por defecto: todo apagado', () {
      const c = ConfigTelemetria();
      expect(c.mqttOn, isFalse);
      expect(c.hookOn, isFalse);
      expect(c.port, 1883);
      expect(c.topic, 'lmb10/coche');
    });

    test('ida y vuelta por JSON conserva los campos', () {
      const c = ConfigTelemetria(
          mqttOn: true, host: '192.168.1.10', port: 8883, user: 'ha',
          pass: 'secreto', topic: 'coche/b10', tls: true,
          hookOn: true, hookUrl: 'https://ejemplo.com/hook');
      final r = ConfigTelemetria.fromJson(c.toJson());
      expect(r.mqttOn, isTrue);
      expect(r.host, '192.168.1.10');
      expect(r.port, 8883);
      expect(r.user, 'ha');
      expect(r.pass, 'secreto');
      expect(r.topic, 'coche/b10');
      expect(r.tls, isTrue);
      expect(r.hookOn, isTrue);
      expect(r.hookUrl, 'https://ejemplo.com/hook');
    });

    test('JSON viejo o incompleto cae en los defaults', () {
      final r = ConfigTelemetria.fromJson({'mqttOn': true});
      expect(r.mqttOn, isTrue);
      expect(r.port, 1883);
      expect(r.topic, 'lmb10/coche');
      expect(r.host, '');
    });

    test('topic vacio en JSON vuelve al default', () {
      final r = ConfigTelemetria.fromJson({'topic': ''});
      expect(r.topic, 'lmb10/coche');
    });
  });
}
