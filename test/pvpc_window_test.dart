// Tests de la ventana contigua mas barata del PVPC.
// Vectores verificados contra una replica del algoritmo.
import 'package:flutter_test/flutter_test.dart';
import 'package:lmb10/pvpc.dart';

void main() {
  group('cheapestWindowHours', () {
    test('elige la ventana contigua mas barata, no las horas sueltas', () {
      // Horas sueltas baratisimas a la 1, 5 y 9 (0.01): ninguna ventana
      // contigua de 3h puede capturar mas de una. La mejor contigua es
      // 14-17 (0.04+0.05+0.06 = 0.15) frente a cualquier ventana con una
      // sola hora barata (0.01+0.20+0.20 = 0.41).
      final horas = List<double>.filled(24, 0.20);
      horas[1] = 0.01;
      horas[5] = 0.01;
      horas[9] = 0.01;
      horas[14] = 0.04;
      horas[15] = 0.05;
      horas[16] = 0.06;
      final (ini, fin) = cheapestWindowHours(horas, 3);
      expect(ini, 14);
      expect(fin, 17);
    });

    test('no cruza medianoche: una ventana 23:00-02:00 no es candidata', () {
      // Las horas 23, 0 y 1 son las mas baratas; si cruzara medianoche la
      // mejor de 3h seria 23-02. Sin cruce: 0-3 y 22-01 empatan a 0.22 y
      // gana la que empieza antes (0-3).
      final horas = List<double>.filled(24, 0.20);
      horas[23] = 0.01;
      horas[0] = 0.01;
      horas[1] = 0.01;
      final (ini, fin) = cheapestWindowHours(horas, 3);
      expect(ini, 0);
      expect(fin, 3);
    });

    test('duracion 24 cubre todo el dia; en empates gana la que empieza antes', () {
      final horas = List<double>.filled(24, 0.15);
      final (ini, fin) = cheapestWindowHours(horas, 24);
      expect((ini, fin), (0, 24));
      final (i2, f2) = cheapestWindowHours(horas, 2);
      expect((i2, f2), (0, 2));
    });
  });
}
