// Tests de las funciones puras del auto-armado por Bluetooth (v157).
// Las puertas baratas, la puerta de red y la regla de desarmado se prueban
// aisladas; la parte con red/plugins queda cubierta por el carlog en
// produccion (lineas SENTRY-AUTOARM).
import 'package:flutter_test/flutter_test.dart';
import 'package:lmb10/sentry/sentry_autoarm.dart';

void main() {
  group('debeArmarPuertas', () {
    test('todo a favor: arma', () {
      expect(
        debeArmarPuertas(enabled: true, conduciendo: false, sinPin: false),
        isTrue,
      );
    });
    test('ajuste desactivado: no arma', () {
      expect(
        debeArmarPuertas(enabled: false, conduciendo: false, sinPin: false),
        isFalse,
      );
    });
    test('conduciendo: no arma', () {
      expect(
        debeArmarPuertas(enabled: true, conduciendo: true, sinPin: false),
        isFalse,
      );
    });
    test('sin PIN recordado: no arma', () {
      expect(
        debeArmarPuertas(enabled: true, conduciendo: false, sinPin: true),
        isFalse,
      );
    });
  });

  group('debeArmarTrasSnapshot', () {
    test('coche encendido: no arma', () {
      expect(debeArmarTrasSnapshot(cocheEncendido: true), isFalse);
    });
    test('coche apagado: arma', () {
      expect(debeArmarTrasSnapshot(cocheEncendido: false), isTrue);
    });
    test('senal desconocida (null): arma igualmente', () {
      expect(debeArmarTrasSnapshot(cocheEncendido: null), isTrue);
    });
  });

  group('debeDesarmar', () {
    test('armado por el auto-armado: desarma', () {
      expect(debeDesarmar(armadoPorAuto: true), isTrue);
    });
    test('armado manual o no armado: no toca nada', () {
      expect(debeDesarmar(armadoPorAuto: false), isFalse);
    });
  });
}
