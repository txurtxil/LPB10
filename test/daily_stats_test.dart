import 'package:flutter_test/flutter_test.dart';
import 'package:lmb10/daily_stats.dart';

void main() {
  // Puntos de prueba: mediodia hora local, para que caigan en el mismo dia
  // sea cual sea la zona horaria de la maquina que corre los tests.
  int ts(int day, int minute) =>
      DateTime(2026, 8, day, 12, minute).millisecondsSinceEpoch;

  group('accumulate', () {
    test('tramo sano acumula km, soc y kmAllRaw', () {
      final days = DailyStats.accumulate([
        [ts(1, 0), 10000, 80.0],
        [ts(1, 10), 10020, 77.0], // 20 km, 3% -> 15%/100km, dentro de rango
      ]);
      final d = days['2026-08-01']!;
      expect(d.km, 20.0);
      expect(d.soc, 3.0);
      expect(d.segs, 1);
      expect(d.pts, 2);
      expect(d.kmAllRaw, 20.0);
    });

    test('tramo con socDelta <= 0 conserva los km reales pero no contamina la media', () {
      final days = DailyStats.accumulate([
        [ts(1, 0), 10000, 80.0],
        [ts(1, 30), 10030, 85.0], // 30 km con subida de soc (carga a mitad)
      ]);
      final d = days['2026-08-01']!;
      expect(d.km, 0.0); // no alimenta la media
      expect(d.soc, 0.0);
      expect(d.segs, 0);
      expect(d.kmAllRaw, 30.0); // pero los km SI se cuentan
    });

    test('tramo con consumo imposible conserva km reales y se descarta para la media', () {
      final days = DailyStats.accumulate([
        [ts(1, 0), 10000, 80.0],
        [ts(1, 5), 10001, 60.0], // 20% en 1 km -> 2000%/100km, imposible
      ]);
      final d = days['2026-08-01']!;
      expect(d.km, 0.0);
      expect(d.kmAllRaw, 1.0);
    });

    test('tramo que cruza medianoche se descarta entero**', () {
      final p1 = DateTime(2026, 8, 1, 23, 50).millisecondsSinceEpoch;
      final p2 = DateTime(2026, 8, 2, 0, 10).millisecondsSinceEpoch;
      final days = DailyStats.accumulate([
        [p1, 10000, 80.0],
        [p2, 10010, 78.0],
      ]);
      expect(days['2026-08-01']!.km, 0.0);
      expect(days['2026-08-01']!.kmAllRaw, 0.0);
      expect(days['2026-08-02']!.km, 0.0);
      expect(days['2026-08-02']!.kmAllRaw, 0.0);
      expect(days['2026-08-01']!.pts, 1);
      expect(days['2026-08-02']!.pts, 1);
    });
  });

  group('fusionaDelta', () {
    test('dia nuevo se inserta tal cual', () {
      final days = <String, DayAgg>{};
      final delta = <String, DayAgg>{
        '2026-08-01': DayAgg('2026-08-01', km: 10, soc: 2, segs: 1, pts: 3, kmAllRaw: 12),
      };
      DailyStats.fusionaDelta(days, delta);
      expect(days['2026-08-01']!.km, 10);
      expect(days['2026-08-01']!.kmAllRaw, 12);
    });

    test('regresion: dia existente suma TODOS los campos, kmAllRaw incluido', () {
      // Antes del fix, la fusion sumaba km/soc/segs/pts pero NO kmAllRaw:
      // los km reales de los tramos nuevos desaparecian de los dias ya
      // cacheados y la guardia de coherencia acababa forzando rebuilds.
      final days = <String, DayAgg>{
        '2026-08-01': DayAgg('2026-08-01', km: 10, soc: 2, segs: 1, pts: 3, kmAllRaw: 12),
      };
      final delta = <String, DayAgg>{
        '2026-08-01': DayAgg('2026-08-01', km: 5, soc: 1, segs: 1, pts: 2, kmAllRaw: 7),
      };
      DailyStats.fusionaDelta(days, delta);
      final d = days['2026-08-01']!;
      expect(d.km, 15);
      expect(d.soc, 3);
      expect(d.segs, 2);
      expect(d.pts, 5);
      expect(d.kmAllRaw, 19); // <- el campo que se perdia
    });
  });

  group('DayAgg.kmAll', () {
    test('respaldo a km cuando kmAllRaw es 0 (agregados antiguos)', () {
      final d = DayAgg('2026-08-01', km: 42, kmAllRaw: 0);
      expect(d.kmAll, 42);
    });
    test('kmAllRaw gana cuando tiene valor', () {
      final d = DayAgg('2026-08-01', km: 40, kmAllRaw: 45);
      expect(d.kmAll, 45);
    });
  });
}
