// Tests de pareceConduccion (v160): la decision de "esto parece ir en
// coche" con la velocidad de iOS y/o el calculo por distancia/tiempo.
import 'package:flutter_test/flutter_test.dart';
import 'package:lmb10/ios_drive_detector.dart';

void main() {
  group('pareceConduccion', () {
    test('velocidad iOS valida y rapida: conduccion', () {
      expect(pareceConduccion(speedMs: 13.9, metrosPorSegundoDist: 0), isTrue);
    });
    test('velocidad iOS valida y lenta (andar): no', () {
      expect(pareceConduccion(speedMs: 1.4, metrosPorSegundoDist: 5), isFalse);
    });
    test('sin velocidad iOS (-1): usa la de distancia, rapida', () {
      expect(pareceConduccion(speedMs: -1, metrosPorSegundoDist: 8.3), isTrue);
    });
    test('sin velocidad iOS (-1): usa la de distancia, lenta', () {
      expect(pareceConduccion(speedMs: -1, metrosPorSegundoDist: 1.4), isFalse);
    });
    test('justo en el umbral (3.5 m/s): no (estricto)', () {
      expect(pareceConduccion(speedMs: 3.5, metrosPorSegundoDist: 0), isFalse);
    });
    test('correr (10 km/h = 2.7 m/s) no es conducir', () {
      expect(pareceConduccion(speedMs: 2.7, metrosPorSegundoDist: 0), isFalse);
    });
    test('bici urbana (18 km/h = 5 m/s) entra (falso positivo aceptado)', () {
      // Documentado en el fichero: inofensivo, solo sondea de mas.
      expect(pareceConduccion(speedMs: 5.0, metrosPorSegundoDist: 0), isTrue);
    });
  });
}
