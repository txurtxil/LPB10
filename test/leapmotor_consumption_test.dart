// Tests de los modelos y la ventana semanal de los endpoints oficiales de
// consumo (getLastNweeks100kmECAndRank / getLastweekEC) y FOTA (cmdId=392).
// Vectores calculados contra la libreria Python de referencia.
import 'package:flutter_test/flutter_test.dart';
import 'package:lmb10/leapmotor_engine.dart';

void main() {
  group('previousWeekWindowSeconds', () {
    test('viernes -> lunes-domingo de la semana anterior en UTC', () {
      final (begin, end) =
          previousWeekWindowSeconds(DateTime.utc(2026, 9, 11, 15, 0, 0));
      expect(begin, 1788134400); // 2026-08-31T00:00:00Z
      expect(end, 1788739199); // 2026-09-06T23:59:59Z
    });

    test('lunes a las 00:00:01 -> la semana que cerro 1 segundo antes', () {
      // Verificado contra previous_week_window_seconds() de la libreria
      // Python: en el borde del lunes la "semana anterior" es la que acaba
      // de cerrarse (31 ago - 6 sep), no la previa a esa.
      final (begin, end) =
          previousWeekWindowSeconds(DateTime.utc(2026, 9, 7, 0, 0, 1));
      expect(begin, 1788134400); // 2026-08-31T00:00:00Z
      expect(end, 1788739199); // 2026-09-06T23:59:59Z
    });

    test('domingo -> la semana anterior, no la que esta en curso', () {
      final (begin, end) =
          previousWeekWindowSeconds(DateTime.utc(2026, 9, 13, 10, 0, 0));
      expect(begin, 1788134400); // 2026-08-31T00:00:00Z
      expect(end, 1788739199); // 2026-09-06T23:59:59Z
    });
  });

  group('ConsumptionWeeklyRank.fromMap', () {
    test('parsea ranking y semanas con valores numericos o string', () {
      final wr = ConsumptionWeeklyRank.fromMap({
        'rankResult': {
          'result': 0,
          'rank': '42%',
          'hundredKmEC': 15.7,
          'hundredMiKwhEC': '25.3',
        },
        'weeklyEC': [
          {
            'weekStart': '2026-08-31',
            'weekEnd': '2026-09-06',
            'hundredKmEC': 14.5,
            'hundredMiKwhEC': 23.3,
          },
          {
            'weekStart': '2026-08-24',
            'weekEnd': '2026-08-30',
            'hundredKmEC': '16.1',
            'hundredMiKwhEC': '25.9',
          },
        ],
      });
      expect(wr.rank.result, 0);
      expect(wr.rank.rank, '42%');
      expect(wr.rank.hundredKmEC, closeTo(15.7, 1e-9));
      expect(wr.rank.hundredMiKwhEC, closeTo(25.3, 1e-9));
      expect(wr.weekly, hasLength(2));
      expect(wr.weekly[0].weekStart, '2026-08-31');
      expect(wr.weekly[1].hundredKmEC, closeTo(16.1, 1e-9));
    });

    test('respuesta vacia no rompe', () {
      final wr = ConsumptionWeeklyRank.fromMap({});
      expect(wr.rank.rank, '');
      expect(wr.weekly, isEmpty);
    });
  });

  group('ConsumptionLastWeekBreakdown.fromMap', () {
    test('la API devuelve STRINGS: se parsean a double y el total cuadra', () {
      final b = ConsumptionLastWeekBreakdown.fromMap({
        'driverEC': '12.30',
        'acEC': '1.50',
        'otherEC': '0.70',
      });
      expect(b.driverEC, closeTo(12.30, 1e-9));
      expect(b.acEC, closeTo(1.50, 1e-9));
      expect(b.otherEC, closeTo(0.70, 1e-9));
      expect(b.totalEC, closeTo(14.50, 1e-9));
    });

    test('valores ausentes caen a cero', () {
      final b = ConsumptionLastWeekBreakdown.fromMap({});
      expect(b.totalEC, 0.0);
    });
  });

}
