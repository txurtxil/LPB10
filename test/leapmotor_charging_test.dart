// Tests del historial oficial de cargas (/carownerservice/charge/daily/detail/page).
import 'package:flutter_test/flutter_test.dart';
import 'package:lmb10/leapmotor_engine.dart';

void main() {
  group('ChargeRecord.fromMap', () {
    test('carga AC completa: epoch ms, kWh y duracion', () {
      final c = ChargeRecord.fromMap({
        'chargeGunStartTs': 1789000000000,
        'chargeGunEndTs': 1789007200000,
        'chargeType': '1',
        'chargeInEnergy': 32.45,
        'chargeStartLongitude': '-2.9867',
        'chargeStartLatitude': '43.2784',
        'zone': 'GMT+02:00',
      });
      expect(c.isFast, isFalse);
      expect(c.energyKwh, closeTo(32.45, 1e-9));
      expect(c.durationSeconds, 7200);
      expect(c.longitude, '-2.9867');
      expect(c.zone, 'GMT+02:00');
    });

    test('chargeType "2" es rapida DC; valores string se aceptan', () {
      final c = ChargeRecord.fromMap({
        'chargeGunStartTs': '1789000000000',
        'chargeGunEndTs': '1789001800000',
        'chargeType': '2',
        'chargeInEnergy': '18.20',
      });
      expect(c.isFast, isTrue);
      expect(c.energyKwh, closeTo(18.20, 1e-9));
      expect(c.durationSeconds, 1800);
    });

    test('tipo desconocido se trata como AC (criterio de la libreria Python)', () {
      final c = ChargeRecord.fromMap({'chargeType': '7'});
      expect(c.isFast, isFalse);
    });

    test('campos ausentes o invertidos no rompen', () {
      final c = ChargeRecord.fromMap({});
      expect(c.startTs, 0);
      expect(c.energyKwh, 0.0);
      expect(c.durationSeconds, 0);
      final invertida = ChargeRecord.fromMap({
        'chargeGunStartTs': 2000,
        'chargeGunEndTs': 1000,
      });
      expect(invertida.durationSeconds, 0);
    });
  });

  group('gmtOffset', () {
    test('formato GMT±HH:MM', () {
      expect(gmtOffset(), matches(RegExp(r'^GMT[+-]\d{2}:\d{2}$')));
    });
  });
}
