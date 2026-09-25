// Tests del resumen por bandas de temperatura (informe PDF de salud).
import 'package:flutter_test/flutter_test.dart';
import 'package:lmb10/consumption_temp.dart';

void main() {
  group('consumoPorBanda', () {
    test('media por banda y null en bandas sin tramos', () {
      final puntos = [
        const PuntoConsumo(0, 40, 10), // <5
        const PuntoConsumo(4, 30, 10), // <5 -> media 35
        const PuntoConsumo(10, 25, 10), // 5-15
        const PuntoConsumo(20, 20, 10), // 15-25
      ];
      final b = consumoPorBanda(puntos);
      expect(b['<5'], closeTo(35.0, 1e-9));
      expect(b['5-15'], closeTo(25.0, 1e-9));
      expect(b['15-25'], closeTo(20.0, 1e-9));
      expect(b['25+'], isNull);
    });

    test('lista vacia: todas las bandas a null', () {
      final b = consumoPorBanda(const []);
      expect(b.values.every((v) => v == null), isTrue);
    });

    test('bordes: 5 y 15 y 25 entran en la banda superior', () {
      final b = consumoPorBanda(const [
        PuntoConsumo(5, 10, 5),
        PuntoConsumo(15, 20, 5),
        PuntoConsumo(25, 30, 5),
      ]);
      expect(b['5-15'], closeTo(10.0, 1e-9));
      expect(b['15-25'], closeTo(20.0, 1e-9));
      expect(b['25+'], closeTo(30.0, 1e-9));
      expect(b['<5'], isNull);
    });
  });
}
