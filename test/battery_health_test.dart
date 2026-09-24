// Tests de la salud de la bateria (N3): estimacion de capacidad por carga
// y descarga pasiva.
import 'package:flutter_test/flutter_test.dart';
import 'package:lmb10/battery_health.dart';

/// Serie de muestras durante una carga: SoC subiendo 20->80 en 2 h con
/// 400 V y 30 A constantes -> energia = 12 kW x 2 h = 24 kWh; 60 % de SoC
/// -> capacidad estimada 40 kWh.
List<MuestraBat> cargaIdeal() {
  final base = DateTime(2026, 9, 1, 22).millisecondsSinceEpoch;
  final out = <MuestraBat>[];
  for (var i = 0; i <= 8; i++) {
    final ts = base + i * 15 * 60000; // cada 15 min
    out.add(MuestraBat(ts, 10000, 20.0 + i * 7.5, v: 400, a: 30));
  }
  return out;
}

void main() {
  group('estimarCapacidades', () {
    test('carga ideal: capacidad = energia / SoC ganado', () {
      final est = estimarCapacidades(cargaIdeal());
      expect(est, hasLength(1));
      expect(est[0].energiaKwh, closeTo(24.0, 1e-6));
      expect(est[0].capacidadKwh, closeTo(40.0, 1e-6));
      expect(est[0].socIni, 20);
      expect(est[0].socFin, 80);
      expect(est[0].cobertura, 60);
    });

    test('sin tension/corriente no hay energia y no estima', () {
      final base = DateTime(2026, 9, 1, 22).millisecondsSinceEpoch;
      final out = <MuestraBat>[];
      for (var i = 0; i <= 8; i++) {
        out.add(MuestraBat(base + i * 15 * 60000, 10000, 20.0 + i * 7.5));
      }
      expect(estimarCapacidades(out), isEmpty);
    });

    test('el SoC contado se capa en el 95 %', () {
      final base = DateTime(2026, 9, 1, 22).millisecondsSinceEpoch;
      final out = <MuestraBat>[];
      // 20 -> 100: la parte 95->100 no cuenta para el SoC ganado
      for (var i = 0; i <= 8; i++) {
        out.add(MuestraBat(base + i * 15 * 60000, 10000, 20.0 + i * 10, v: 400, a: 30));
      }
      final est = estimarCapacidades(out);
      expect(est, hasLength(1));
      expect(est[0].socFin, 95);
      // ganancia contada: 75 % -> 24 kWh / 0.75 = 32 kWh
      expect(est[0].capacidadKwh, closeTo(32.0, 1e-6));
    });

    test('dos cargas separadas por un viaje dan dos estimaciones', () {
      final m = cargaIdeal();
      final fin = m.last.ts;
      // viaje: km avanza, SoC baja (sin v/a: no son parte de ninguna carga)
      m.add(MuestraBat(fin + 3600000, 10050, 50));
      m.add(MuestraBat(fin + 7200000, 10100, 40));
      // segunda carga 40 -> 80 (40 %) misma potencia 2 h -> 24/0.4 = 60 kWh
      // (empieza 1 min despues del ultimo punto del viaje: timestamps
      // identicos se descartan como duplicados)
      final b2 = fin + 7200000 + 60000;
      for (var i = 0; i <= 8; i++) {
        m.add(MuestraBat(b2 + i * 15 * 60000, 10100, 40.0 + i * 5, v: 400, a: 30));
      }
      final est = estimarCapacidades(m);
      expect(est, hasLength(2));
      expect(est[1].capacidadKwh, closeTo(60.0, 1e-6));
    });

    test('subida de SoC menor al minimo se descarta', () {
      final base = DateTime(2026, 9, 1, 22).millisecondsSinceEpoch;
      final out = <MuestraBat>[];
      for (var i = 0; i <= 8; i++) {
        out.add(MuestraBat(base + i * 15 * 60000, 10000, 50.0 + i, v: 400, a: 30));
      }
      expect(estimarCapacidades(out), isEmpty);
    });

    test('carga demasiado corta se descarta', () {
      final base = DateTime(2026, 9, 1, 22).millisecondsSinceEpoch;
      final out = <MuestraBat>[];
      // 30 % de SoC en 5 minutos: ganancia ok pero duracion no
      for (var i = 0; i <= 4; i++) {
        out.add(MuestraBat(base + i * 60000, 10000, 50.0 + i * 7.5, v: 400, a: 30));
      }
      expect(estimarCapacidades(out), isEmpty);
    });

    test('capacidad fuera de rango plausible se descarta', () {
      final base = DateTime(2026, 9, 1, 22).millisecondsSinceEpoch;
      final out = <MuestraBat>[];
      // Potencia ridiculamente baja para el SoC que sube -> capacidad < 20
      for (var i = 0; i <= 8; i++) {
        out.add(MuestraBat(base + i * 15 * 60000, 10000, 20.0 + i * 7.5, v: 100, a: 1));
      }
      expect(estimarCapacidades(out), isEmpty);
    });
  });

  group('resumirSalud', () {
    test('media ponderada por cobertura y dispersion', () {
      final base = DateTime(2026, 9, 1).millisecondsSinceEpoch;
      final est = [
        EstimacionCarga(iniMs: base, finMs: base + 1, socIni: 20, socFin: 80, energiaKwh: 24, capacidadKwh: 40),
        EstimacionCarga(iniMs: base + 2, finMs: base + 3, socIni: 30, socFin: 60, energiaKwh: 13.5, capacidadKwh: 45),
      ];
      final r = resumirSalud(est);
      // pesos 60 y 30 -> (40*60 + 45*30)/90 = 41.666...
      expect(r.capacidadKwh, closeTo(41.6667, 1e-3));
      expect(r.numEstimaciones, 2);
      expect(r.dispersionPct, isNotNull);
      expect(r.dispersionPct!, greaterThan(0));
    });

    test('sin estimaciones no hay cifra', () {
      final r = resumirSalud(const []);
      expect(r.capacidadKwh, isNull);
      expect(r.numEstimaciones, 0);
    });
  });

  group('calcularDescargaPasiva', () {
    test('parada con perdida normalizada a %/dia', () {
      final base = DateTime(2026, 9, 20, 23).millisecondsSinceEpoch;
      final m = <MuestraBat>[
        MuestraBat(base, 10000, 60),
        MuestraBat(base + 12 * 3600000, 10000, 58), // -2 % en 12 h
        MuestraBat(base + 12 * 3600000 + 1, 10100, 58), // arranca
      ];
      final p = calcularDescargaPasiva(m);
      expect(p, hasLength(1));
      expect(p[0].perdidaPct, closeTo(2.0, 1e-9));
      expect(p[0].pctDia, closeTo(4.0, 1e-9)); // 2 % / 12 h -> 4 %/dia
    });

    test('caida menor que el ruido no cuenta', () {
      final base = DateTime(2026, 9, 20, 23).millisecondsSinceEpoch;
      final m = <MuestraBat>[
        MuestraBat(base, 10000, 60),
        MuestraBat(base + 12 * 3600000, 10000, 59.9),
      ];
      expect(calcularDescargaPasiva(m), isEmpty);
    });

    test('sin cambio de km ni SoC no hay parada', () {
      final base = DateTime(2026, 9, 20, 23).millisecondsSinceEpoch;
      final m = <MuestraBat>[
        MuestraBat(base, 10000, 60),
        MuestraBat(base + 12 * 3600000, 10000, 60),
      ];
      expect(calcularDescargaPasiva(m), isEmpty);
    });
  });

  group('mediana', () {
    test('lista impar y par', () {
      expect(mediana([1, 5, 3]), 3);
      expect(mediana([1, 4, 3, 5]), closeTo(3.5, 1e-9));
      expect(mediana([]), isNull);
    });
  });
}
