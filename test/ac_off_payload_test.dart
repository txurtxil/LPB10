import 'package:flutter_test/flutter_test.dart';
import 'package:lmb10/leapmotor_engine.dart';

void main() {
  // v214: regression del AC off. Antes operate='close': el T03 lo ignoraba
  // (la nube devuelve code=0 igual) y el B10 solo pasaba el HVAC a AUTO.
  // La API espera operate='off'.
  group('kAcOffPayload', () {
    test('usa operate=off, nunca close', () {
      expect(kAcOffPayload, contains('"operate":"off"'));
      expect(kAcOffPayload, isNot(contains('"operate":"close"')));
    });

    test('mantiene el resto de campos del comando de clima', () {
      for (final campo in [
        'circle', 'mode', 'position', 'temperature', 'windlevel', 'wshld'
      ]) {
        expect(kAcOffPayload, contains('"$campo"'));
      }
    });
  });
}
