import 'package:flutter_test/flutter_test.dart';
import 'package:lmb10/leapmotor_engine.dart';

void main() {
  // v215: el B05 responde por la ruta de estado C10 (markoceri/leapmotor-api,
  // oct 2026), igual que el B10/B11.
  group('statusPath B05', () {
    test('B05 -> c10 directo', () {
      final v = Vehicle(vin: 'VINB05', carType: 'b05');
      expect(v.statusPath, 'c10');
    });

    test('candidatos del B05 solo c10', () {
      final v = Vehicle(vin: 'VINB05', carType: 'B05');
      expect(v.statusPathCandidates, ['c10']);
    });

    test('B10/B11 siguen igual', () {
      expect(Vehicle(vin: 'V1', carType: 'b10').statusPath, 'c10');
      expect(Vehicle(vin: 'V2', carType: 'b11').statusPath, 'c10');
    });

    test('candidatos del B03X (a10) siguen igual', () {
      final v = Vehicle(vin: 'V3', carType: 'a10');
      expect(v.statusPathCandidates.first, 'a10');
      expect(v.statusPathCandidates, contains('t03'));
      expect(v.statusPathCandidates, contains('c10'));
      expect(v.statusPathCandidates, contains('c11'));
      expect(v.statusPathCandidates, contains('b03'));
    });
  });
}
