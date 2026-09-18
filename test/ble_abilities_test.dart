import 'package:flutter_test/flutter_test.dart';
import 'package:lmb10/leapmotor_engine.dart';

void main() {
  group('abilitiesReport', () {
    test('lista nula o ausente lo dice sin romper', () {
      expect(abilitiesReport(null), contains('ausente o vacia'));
      expect(abilitiesReport([]), contains('ausente o vacia'));
      expect(abilitiesReport('texto'), contains('ausente o vacia'));
    });

    test('decodifica ids conocidos con su nombre', () {
      final out = abilitiesReport([16, 53, 10]);
      expect(out, contains('16 = BLE_KEY'));
      expect(out, contains('53 = BLE_KEY_RESTART'));
      expect(out, contains('10 = LOCK_UNLOCK'));
      expect(out, contains('abilities (3):'));
    });

    test('marca las pistas BLE-KEY (16, 30, 49, 53)', () {
      final conPistas = abilitiesReport([16, 49, 5]);
      expect(conPistas, contains('16 = BLE_KEY   <== PISTA BLE-KEY'));
      expect(conPistas, contains('49 = PARKING_PHOTO   <== PISTA BLE-KEY'));
      expect(conPistas, isNot(contains('5 = GPS   <== PISTA BLE-KEY')));
    });

    test('ids desconocidos no rompen y salen como DESCONOCIDA', () {
      final out = abilitiesReport([999]);
      expect(out, contains('999 = DESCONOCIDA'));
    });

    test('acepta ids como strings (el servidor a veces manda strings)', () {
      final out = abilitiesReport(['16', '30']);
      expect(out, contains('16 = BLE_KEY'));
      expect(out, contains('30 = GPS_SHARING'));
    });

    test('el resumen SI/NO refleja presencia y ausencia', () {
      final out = abilitiesReport([16, 30]);
      expect(out, contains('[SI] 16 BLE_KEY declarada'));
      expect(out, contains('[SI] 30 GPS_SHARING declarada'));
      expect(out, contains('[NO] 49 PARKING_PHOTO NO declarada'));
      expect(out, contains('[NO] 53 BLE_KEY_RESTART NO declarada'));
    });

    test('ordena los ids de menor a mayor', () {
      final out = abilitiesReport([53, 5, 16]);
      final i5 = out.indexOf('5 = GPS');
      final i16 = out.indexOf('16 = BLE_KEY');
      final i53 = out.indexOf('53 = BLE_KEY_RESTART');
      expect(i5, lessThan(i16));
      expect(i16, lessThan(i53));
    });
  });

  group('kAbilityNames', () {
    test('contiene las cuatro abilities clave de la investigacion', () {
      expect(kAbilityNames[16], 'BLE_KEY');
      expect(kAbilityNames[30], 'GPS_SHARING');
      expect(kAbilityNames[49], 'PARKING_PHOTO');
      expect(kAbilityNames[53], 'BLE_KEY_RESTART');
    });
  });
}
