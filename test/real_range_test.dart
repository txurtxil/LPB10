import 'package:flutter_test/flutter_test.dart';
import 'package:lmb10/daily_stats.dart';
import 'package:lmb10/real_range.dart';
import 'package:lmb10/widget_chart.dart' show gMaxRangeKm;

DayAgg dia(String d, double km, double soc, {int pts = 50}) =>
    DayAgg(d, km: km, soc: soc, pts: pts);

void main() {
  // B10: 67,1 kWh / 430 km -> ~23,3 %/100km de consumo tipico.
  final now = DateTime(2026, 9, 18, 12, 0);

  group('computeRealRange', () {
    test('sin datos devuelve null', () {
      expect(computeRealRange(<DayAgg>[], 80.0, now: now), isNull);
    });

    test('menos de 5 km de base devuelve null', () {
      final days = [dia('2026-09-17', 3.0, 0.7)];
      expect(computeRealRange(days, 80.0, now: now), isNull);
    });

    test('media implausible devuelve null', () {
      // 200 km con 2% de bateria: fisicamente imposible, red de seguridad.
      final days = [dia('2026-09-17', 200.0, 2.0)];
      expect(computeRealRange(days, 80.0, now: now), isNull);
    });

    test('usa los ultimos 30 dias cuando hay 50+ km recientes', () {
      final days = [
        // Historico antiguo con consumo alto (invierno pasado).
        dia('2026-01-10', 300.0, 90.0), // 30 %/100km
        // Reciente: 20 %/100km.
        dia('2026-09-10', 60.0, 12.0),
        dia('2026-09-15', 40.0, 8.0),
      ];
      final e = computeRealRange(days, 50.0, now: now)!;
      expect(e.ventana30d, isTrue);
      expect(e.kmBase, closeTo(100.0, 0.01));
      expect(e.pctPer100km, closeTo(20.0, 0.01));
      expect(e.rangeNowKm, (50.0 / 20.0 * 100).round());
      expect(e.kwh100, closeTo(20.0 / 100.0 * 67.1, 0.01));
    });

    test('cae al historico completo si los 30 dias tienen pocos km', () {
      final days = [
        dia('2026-06-01', 100.0, 25.0), // 25 %/100km
        dia('2026-09-15', 10.0, 2.0), // reciente pero insuficiente
      ];
      final e = computeRealRange(days, 80.0, now: now)!;
      expect(e.ventana30d, isFalse);
      expect(e.kmBase, closeTo(110.0, 0.01));
      expect(e.pctPer100km, closeTo(27.0 / 110.0 * 100.0, 0.01));
    });

    test('la autonomia al 100% se capa a la fisica del coche', () {
      // Consumo irrealmente bajo pero plausible: 12 %/100km -> 833 km > 430.
      final days = [dia('2026-09-10', 100.0, 12.0)];
      final e = computeRealRange(days, 100.0, now: now)!;
      expect(e.rangeFullKm, gMaxRangeKm.round());
      expect(e.rangeNowKm, gMaxRangeKm.round());
    });

    test('soc nulo no rompe y da rangeNow 0', () {
      final days = [dia('2026-09-10', 100.0, 23.3)];
      final e = computeRealRange(days, null, now: now)!;
      expect(e.rangeNowKm, 0);
      expect(e.rangeFullKm, greaterThan(0));
    });

    test('ignora filas rollup de semana/mes', () {
      final days = [
        DayAgg('2026-S37', km: 500.0, soc: 100.0),
        DayAgg('2026-09', km: 500.0, soc: 100.0),
        dia('2026-09-10', 100.0, 23.3),
      ];
      final e = computeRealRange(days, 50.0, now: now)!;
      expect(e.kmBase, closeTo(100.0, 0.01));
    });

    test('dias justo en el corte de 30 dias cuentan como recientes', () {
      final days = [
        dia('2026-08-19', 200.0, 60.0), // 30 %/100km, justo en el corte
        dia('2026-08-18', 200.0, 40.0), // 20 %/100km, un dia fuera
      ];
      final e = computeRealRange(days, 50.0, now: now)!;
      expect(e.ventana30d, isTrue);
      expect(e.kmBase, closeTo(200.0, 0.01));
      expect(e.pctPer100km, closeTo(30.0, 0.01));
    });
  });

  group('puntosDe', () {
    test('suma pts solo de filas diarias', () {
      final days = [
        dia('2026-09-10', 10, 2, pts: 30),
        dia('2026-09-11', 10, 2, pts: 40),
        DayAgg('2026-S37', km: 20, soc: 4, pts: 70),
      ];
      expect(puntosDe(days), 70);
    });
  });
}
