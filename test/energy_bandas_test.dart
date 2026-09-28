// Tests de la tarifa por tramos 2.0TD (punta/llano/valle).
import 'package:flutter_test/flutter_test.dart';
import 'package:lmb10/energy_cost.dart';

void main() {
  group('tramo2_0TD', () {
    // Lunes 5 de octubre de 2026 (laborable).
    DateTime lab(int h, [int m = 0]) => DateTime(2026, 10, 5, h, m);

    test('punta: laborables 10-14 y 18-22', () {
      expect(EnergyPrice.tramo2_0TD(lab(10)), 1);
      expect(EnergyPrice.tramo2_0TD(lab(13, 59)), 1);
      expect(EnergyPrice.tramo2_0TD(lab(18)), 1);
      expect(EnergyPrice.tramo2_0TD(lab(21, 59)), 1);
    });

    test('llano: laborables 8-10, 14-18 y 22-24', () {
      expect(EnergyPrice.tramo2_0TD(lab(8)), 2);
      expect(EnergyPrice.tramo2_0TD(lab(9, 59)), 2);
      expect(EnergyPrice.tramo2_0TD(lab(14)), 2);
      expect(EnergyPrice.tramo2_0TD(lab(17, 59)), 2);
      expect(EnergyPrice.tramo2_0TD(lab(22)), 2);
      expect(EnergyPrice.tramo2_0TD(lab(23, 59)), 2);
    });

    test('valle: laborables 0-8', () {
      expect(EnergyPrice.tramo2_0TD(lab(0)), 3);
      expect(EnergyPrice.tramo2_0TD(lab(7, 59)), 3);
    });

    test('fin de semana: valle todo el dia, tambien a mediodia', () {
      expect(EnergyPrice.tramo2_0TD(DateTime(2026, 10, 10, 12)), 3); // sabado
      expect(EnergyPrice.tramo2_0TD(DateTime(2026, 10, 11, 19)), 3); // domingo
      expect(EnergyPrice.tramo2_0TD(DateTime(2026, 10, 11, 0)), 3);
    });
  });

  group('precioFranjaBandas', () {
    const p1 = 0.20, p2 = 0.15, p3 = 0.10;

    test('carga nocturna 23:00-07:00 = 1h llano + 7h valle', () {
      final v = EnergyPrice.precioFranjaBandas(
          p1, p2, p3, DateTime(2026, 10, 5, 23), DateTime(2026, 10, 6, 7));
      expect(v, closeTo((0.15 + 7 * 0.10) / 8, 1e-9));
    });

    test('carga solo en punta cobra P1', () {
      final v = EnergyPrice.precioFranjaBandas(
          p1, p2, p3, DateTime(2026, 10, 5, 18), DateTime(2026, 10, 5, 22));
      expect(v, p1);
    });

    test('carga sabado por la manana cobra P3 todo', () {
      final v = EnergyPrice.precioFranjaBandas(
          p1, p2, p3, DateTime(2026, 10, 10, 9), DateTime(2026, 10, 10, 13));
      expect(v, p3);
    });

    test('intervalo invalido devuelve null', () {
      expect(
          EnergyPrice.precioFranjaBandas(
              p1, p2, p3, DateTime(2026, 10, 5, 10), DateTime(2026, 10, 5, 10)),
          isNull);
    });
  });

  group('mediaSemanalBandas', () {
    test('5 laborables con 8 h de cada tramo + fin de semana en valle', () {
      expect(EnergyPrice.mediaSemanalBandas(0.20, 0.15, 0.10),
          closeTo((5 * (8 * 0.20 + 8 * 0.15 + 8 * 0.10) + 48 * 0.10) / 168.0, 1e-9));
    });

    test('tres precios iguales devuelven ese precio', () {
      expect(EnergyPrice.mediaSemanalBandas(0.12, 0.12, 0.12),
          closeTo(0.12, 1e-12));
    });
  });
}
