// Tests de la curva de potencia de sesion y la eficiencia real de carga.
import 'package:flutter_test/flutter_test.dart';
import 'package:lmb10/battery_health.dart' show MuestraBat;
import 'package:lmb10/charging_costs.dart';

void main() {
  group('curvaPotencia', () {
    test('solo puntos dentro de la ventana con v y a', () {
      final base = DateTime(2026, 9, 1, 22).millisecondsSinceEpoch;
      final m = <MuestraBat>[
        MuestraBat(base - 60000, 10000, 19, v: 400, a: 10), // fuera
        MuestraBat(base, 10000, 20, v: 400, a: 10), // 4 kW
        MuestraBat(base + 60000, 10000, 21), // sin v/a: se salta
        MuestraBat(base + 120000, 10000, 22, v: 380, a: 20), // 7.6 kW
        MuestraBat(base + 180000, 10000, 23, v: 400, a: 10),
      ];
      final c = curvaPotencia(m, base, base + 120000);
      expect(c, hasLength(2));
      expect(c[0].$1, base);
      expect(c[0].$2, closeTo(4.0, 1e-9));
      expect(c[1].$2, closeTo(7.6, 1e-9));
    });

    test('corriente negativa cuenta por su valor absoluto', () {
      final base = DateTime(2026, 9, 1, 22).millisecondsSinceEpoch;
      final c = curvaPotencia(
          [MuestraBat(base, 10000, 50, v: 400, a: -25)], base, base);
      expect(c[0].$2, closeTo(10.0, 1e-9));
    });
  });

  group('eficienciaReal', () {
    test('kWh paquete / kWh cargador', () {
      expect(eficienciaReal(34.0, 40.0), closeTo(85.0, 1e-9));
    });
    test('sin dato del cargador o a cero: null', () {
      expect(eficienciaReal(34.0, null), isNull);
      expect(eficienciaReal(34.0, 0), isNull);
    });
  });
}
