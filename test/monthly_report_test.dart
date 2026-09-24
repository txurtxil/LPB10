// Tests del informe mensual automatico (I1): claves de mes, regla de
// disparo y cuentas del resumen.
import 'package:flutter_test/flutter_test.dart';
import 'package:lmb10/monthly_report.dart';

void main() {
  group('mesKeyDe / mesAnteriorKey', () {
    test('clave con cero a la izquierda', () {
      expect(mesKeyDe(DateTime(2026, 3, 5)), '2026-03');
      expect(mesKeyDe(DateTime(2026, 12, 5)), '2026-12');
    });

    test('mes anterior simple', () {
      expect(mesAnteriorKey('2026-09'), '2026-08');
    });

    test('cambio de ano', () {
      expect(mesAnteriorKey('2026-01'), '2025-12');
    });

    test('enero de 2027 vuelve a diciembre de 2026', () {
      expect(mesAnteriorKey('2027-01'), '2026-12');
    });
  });

  group('debeGenerarInforme', () {
    test('dispara el dia 1 si no se genero el mes anterior', () {
      expect(
        debeGenerarInforme(ahora: DateTime(2026, 10, 1), ultimoGenerado: null),
        isTrue,
      );
      expect(
        debeGenerarInforme(
            ahora: DateTime(2026, 10, 1), ultimoGenerado: '2026-08'),
        isTrue,
      );
    });

    test('no dispara si ya se genero para el mes anterior', () {
      expect(
        debeGenerarInforme(
            ahora: DateTime(2026, 10, 3), ultimoGenerado: '2026-09'),
        isFalse,
      );
    });

    test('dispara tras el dia 1 si aun no se genero (primer ciclo disponible)', () {
      expect(
        debeGenerarInforme(
            ahora: DateTime(2026, 10, 5), ultimoGenerado: '2026-08'),
        isTrue,
      );
    });

    test('no dispara pasada la semana de disparo', () {
      expect(
        debeGenerarInforme(
            ahora: DateTime(2026, 10, 8), ultimoGenerado: '2026-08'),
        isFalse,
      );
    });
  });

  group('computeResumenInforme', () {
    const mes = DatosMes(
      mesKey: '2026-09',
      km: 1000,
      kwhConsumidos: 160,
      kwhCargados: 170,
      euros: 25,
      cargas: 6,
    );

    test('coste y consumo por 100 km', () {
      final r = computeResumenInforme(mes: mes);
      expect(r.coste100km, closeTo(2.5, 1e-9));
      expect(r.consumo100km, closeTo(16.0, 1e-9));
    });

    test('sin kilometraje no hay consumo ni coste', () {
      final r = computeResumenInforme(
          mes: const DatosMes(mesKey: '2026-09', euros: 10, cargas: 2));
      expect(r.coste100km, isNull);
      expect(r.consumo100km, isNull);
    });

    test('CO2 evitado y ahorro frente al termico', () {
      final r = computeResumenInforme(
          mes: mes, litros100: 6.0, precioLitro: 1.50);
      // 1000 km * 6 l/100 = 60 l * 2.31 kg/l = 138.6 kg
      expect(r.co2EvitadoKg, closeTo(138.6, 1e-9));
      // 60 l * 1.50 EUR = 90 EUR - 25 EUR = 65 EUR ahorrados
      expect(r.eurosAhorrados, closeTo(65.0, 1e-9));
    });

    test('sin termico configurado no hay CO2 ni ahorro', () {
      final r = computeResumenInforme(mes: mes);
      expect(r.co2EvitadoKg, isNull);
      expect(r.eurosAhorrados, isNull);
    });

    test('comparativa porcentual con el mes anterior', () {
      const ant = DatosMes(mesKey: '2026-08', km: 800, euros: 22);
      final r = computeResumenInforme(mes: mes, anterior: ant);
      expect(r.difKmPct, closeTo(25.0, 1e-9));
      // (2.5 - 2.75) / 2.75 * 100 = -9.0909...
      expect(r.difCoste100Pct, closeTo(-9.0909, 1e-3));
      expect(r.difEurosPct, closeTo((25 - 22) / 22 * 100, 1e-9));
    });

    test('sin mes anterior no hay comparativa', () {
      final r = computeResumenInforme(mes: mes);
      expect(r.difKmPct, isNull);
      expect(r.difCoste100Pct, isNull);
      expect(r.difEurosPct, isNull);
    });

    test('comparativa de coste nula si el anterior no tiene coste', () {
      const ant = DatosMes(mesKey: '2026-08', km: 800, euros: 0);
      final r = computeResumenInforme(mes: mes, anterior: ant);
      expect(r.difKmPct, isNotNull);
      expect(r.difCoste100Pct, isNull);
    });
  });
}
