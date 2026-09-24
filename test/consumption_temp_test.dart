// Tests de consumo segun temperatura (clon Mate) y del parseo de
// Open-Meteo.
import 'package:flutter_test/flutter_test.dart';
import 'package:lmb10/battery_health.dart' show MuestraBat;
import 'package:lmb10/consumption_temp.dart';
import 'package:lmb10/exterior_temp.dart';

void main() {
  group('consumoVsTemp', () {
    test('consumo por encima del rango plausible se descarta', () {
      final base = DateTime(2026, 9, 10, 8).millisecondsSinceEpoch;
      // 10 km, -5 % de SoC -> 50 %/100 km: fisicamente imposible, es ruido
      final m = <MuestraBat>[
        for (var i = 0; i <= 5; i++)
          MuestraBat(base + i * 60000, 10000 + i * 2, 60.0 - i, te: 12),
      ];
      expect(consumoVsTemp(m), isEmpty);
    });

    test('consumo dentro de rango plausible puntua', () {
      final base = DateTime(2026, 9, 10, 8).millisecondsSinceEpoch;
      // 10 km, -2.5 % -> 25 %/100 km, temp media 12
      final m = <MuestraBat>[
        for (var i = 0; i <= 5; i++)
          MuestraBat(base + i * 60000, 10000 + i * 2, 60.0 - i * 0.5, te: 12),
      ];
      final p = consumoVsTemp(m);
      expect(p, hasLength(1));
      expect(p[0].temp, closeTo(12.0, 1e-9));
      expect(p[0].pct100km, closeTo(25.0, 1e-9));
      expect(p[0].km, closeTo(10.0, 1e-9));
    });

    test('una carga a mitad parte el tramo en dos', () {
      final base = DateTime(2026, 9, 10, 8).millisecondsSinceEpoch;
      final m = <MuestraBat>[
        for (var i = 0; i <= 3; i++)
          MuestraBat(base + i * 60000, 10000 + i * 2, 60.0 - i * 0.5, te: 10),
        // carga: SoC sube
        MuestraBat(base + 4 * 60000, 10006, 70, te: 10),
        // segundo tramo
        for (var i = 5; i <= 8; i++)
          MuestraBat(base + i * 60000, 10006 + (i - 4) * 2, 70.0 - (i - 4) * 0.5, te: 20),
      ];
      final p = consumoVsTemp(m);
      expect(p, hasLength(2));
      expect(p[0].temp, closeTo(10.0, 1e-9));
      expect(p[1].temp, closeTo(20.0, 1e-9));
    });

    test('sin temperatura en todo el tramo no hay punto', () {
      final base = DateTime(2026, 9, 10, 8).millisecondsSinceEpoch;
      final m = <MuestraBat>[
        for (var i = 0; i <= 5; i++)
          MuestraBat(base + i * 60000, 10000 + i * 2, 60.0 - i * 0.5),
      ];
      expect(consumoVsTemp(m), isEmpty);
    });

    test('usa la temperatura del paquete si no hay exterior', () {
      final base = DateTime(2026, 9, 10, 8).millisecondsSinceEpoch;
      final m = <MuestraBat>[
        for (var i = 0; i <= 5; i++)
          MuestraBat(base + i * 60000, 10000 + i * 2, 60.0 - i * 0.5, t: 18),
      ];
      final p = consumoVsTemp(m);
      expect(p, hasLength(1));
      expect(p[0].temp, closeTo(18.0, 1e-9));
    });

    test('tramo de menos de 2 km no puntua', () {
      final base = DateTime(2026, 9, 10, 8).millisecondsSinceEpoch;
      final m = <MuestraBat>[
        MuestraBat(base, 10000, 60, te: 15),
        MuestraBat(base + 60000, 10001, 59.5, te: 15),
      ];
      expect(consumoVsTemp(m), isEmpty);
    });
  });

  group('ExteriorTemp.parsearTemp', () {
    test('respuesta valida de Open-Meteo', () {
      const body = '{"latitude":43.38,"longitude":-1.79,'
          '"current":{"time":"2026-09-24T10:00","temperature_2m":19.4}}';
      expect(ExteriorTemp.parsearTemp(body), closeTo(19.4, 1e-9));
    });

    test('cuerpo invalido o sin temperatura da null', () {
      expect(ExteriorTemp.parsearTemp('no json'), isNull);
      expect(ExteriorTemp.parsearTemp('{}'), isNull);
      expect(ExteriorTemp.parsearTemp('{"current":{}}'), isNull);
      expect(ExteriorTemp.parsearTemp('[1,2,3]'), isNull);
    });
  });
}
