// Tests del cmdContent de send_destination (cmdId=180): el JSON debe
// salir compacto, con las claves en el orden exacto de la referencia
// Python y las coordenadas como STRING.
import 'package:flutter_test/flutter_test.dart';
import 'package:lmb10/leapmotor_engine.dart';

void main() {
  group('destinationCmdContent', () {
    test('formato exacto: claves ordenadas, compacto, coords string', () {
      final c = destinationCmdContent(
        address: 'Calle Mayor 1, Madrid',
        addressName: 'Casa',
        latitude: 40.4168,
        longitude: -3.7038,
      );
      expect(
        c,
        '{"address":"Calle Mayor 1, Madrid","addressname":"Casa",'
        '"latitude":"40.4168","linenum":"0","longitude":"-3.7038"}',
      );
    });

    test('no escapa caracteres no ASCII (ensure_ascii=False de la referencia)', () {
      final c = destinationCmdContent(
        address: 'Avenida de José Antonio, Móstoles',
        addressName: 'Taller Peña',
        latitude: 40.3223,
        longitude: -3.865,
      );
      expect(c, contains('José'));
      expect(c, contains('Móstoles'));
      expect(c, contains('Peña'));
      expect(c, isNot(contains(r'\u')));
    });
  });
}
