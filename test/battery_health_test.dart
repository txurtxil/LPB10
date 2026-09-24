// Tests de la salud de la bateria (N3/N3b): estimacion de capacidad por
// carga (con corriente minima y corte por frio) y descarga pasiva (con
// agregado perdida total / tiempo total, estilo LeapMotor Mate).
import 'package:flutter_test/flutter_test.dart';
import 'package:lmb10/battery_health.dart';

/// Serie de muestras durante una carga: SoC subiendo 20->80 en 2 h con
/// 400 V y 30 A constantes -> energia = 12 kW x 2 h = 24 kWh; 60 % de SoC
/// -> capacidad estimada 40 kWh.
List<MuestraBat> cargaIdeal({double? t, double a = 30}) {
  final base = DateTime(2026, 9, 1, 22).millisecondsSinceEpoch;
  final out = <MuestraBat>[];
  for (var i = 0; i <= 8; i++) {
    final ts = base + i * 15 * 60000; // cada 15 min
    out.add(MuestraBat(ts, 10000, 20.0 + i * 7.5, v: 400, a: a, t: t));
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
      expect(est[0].excluida, isFalse);
      expect(est[0].tempMin, isNull);
    });

    test('sin tension/corriente no hay energia y no estima', () {
      final base = DateTime(2026, 9, 1, 22).millisecondsSinceEpoch;
      final out = <MuestraBat>[];
      for (var i = 0; i <= 8; i++) {
        out.add(MuestraBat(base + i * 15 * 60000, 10000, 20.0 + i * 7.5));
      }
      expect(estimarCapacidades(out), isEmpty);
    });

    test('corriente por debajo del minimo no aporta energia', () {
      // 1.5 A < 2 A: un coche enchufado a corriente infima cuenta como
      // parado, no como carga (criterio Mate).
      expect(estimarCapacidades(cargaIdeal(a: 1.5)), isEmpty);
    });

    test('carga con bateria fria se marca excluida y guarda su tempMin', () {
      final est = estimarCapacidades(cargaIdeal(t: 10));
      expect(est, hasLength(1));
      expect(est[0].excluida, isTrue);
      expect(est[0].tempMin, closeTo(10.0, 1e-9));
    });

    test('tempMin es la minima temperatura vista durante la carga', () {
      final base = DateTime(2026, 9, 1, 22).millisecondsSinceEpoch;
      final out = <MuestraBat>[];
      for (var i = 0; i <= 8; i++) {
        out.add(MuestraBat(base + i * 15 * 60000, 10000, 20.0 + i * 7.5,
            v: 400, a: 30, t: 20.0 - i)); // 20, 19, ..., 12
      }
      final est = estimarCapacidades(out);
      expect(est, hasLength(1));
      expect(est[0].tempMin, closeTo(12.0, 1e-9));
      expect(est[0].excluida, isTrue);
    });

    test('carga justo en el corte de frio (15 C) NO se excluye', () {
      final est = estimarCapacidades(cargaIdeal(t: 15));
      expect(est, hasLength(1));
      expect(est[0].excluida, isFalse);
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
        out.add(MuestraBat(base + i * 15 * 60000, 10000, 20.0 + i * 7.5, v: 100, a: 3));
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

    test('las cargas excluidas por frio no entran en la media', () {
      final base = DateTime(2026, 9, 1).millisecondsSinceEpoch;
      final est = [
        EstimacionCarga(iniMs: base, finMs: base + 1, socIni: 20, socFin: 80, energiaKwh: 24, capacidadKwh: 40),
        EstimacionCarga(iniMs: base + 2, finMs: base + 3, socIni: 20, socFin: 80, energiaKwh: 20, capacidadKwh: 30, tempMin: 8, excluida: true),
      ];
      final r = resumirSalud(est);
      // solo cuenta la de 40 kWh; la fria (30) se queda fuera
      expect(r.capacidadKwh, closeTo(40.0, 1e-9));
      expect(r.numEstimaciones, 2);
      expect(r.excluidasFrio, 1);
      expect(r.estimaciones, hasLength(2)); // la fria sigue en el historico
    });

    test('todas frias: no hay cifra pero se cuentan', () {
      final base = DateTime(2026, 9, 1).millisecondsSinceEpoch;
      final est = [
        EstimacionCarga(iniMs: base, finMs: base + 1, socIni: 20, socFin: 80, energiaKwh: 20, capacidadKwh: 30, tempMin: 5, excluida: true),
      ];
      final r = resumirSalud(est);
      expect(r.capacidadKwh, isNull);
      expect(r.numEstimaciones, 1);
      expect(r.excluidasFrio, 1);
    });

    test('sin estimaciones no hay cifra', () {
      final r = resumirSalud(const []);
      expect(r.capacidadKwh, isNull);
      expect(r.numEstimaciones, 0);
      expect(r.excluidasFrio, 0);
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
      expect(p[0].esRuido, isFalse);
    });

    test('caida menor que el ruido se guarda pero marcada como ruido', () {
      final base = DateTime(2026, 9, 20, 23).millisecondsSinceEpoch;
      final m = <MuestraBat>[
        MuestraBat(base, 10000, 60),
        MuestraBat(base + 12 * 3600000, 10000, 59.9),
      ];
      final p = calcularDescargaPasiva(m);
      expect(p, hasLength(1));
      expect(p[0].esRuido, isTrue);
      expect(p[0].perdidaPct, closeTo(0.1, 1e-9));
    });

    test('parada sin perdida tambien cuenta (entra en el tiempo total)', () {
      final base = DateTime(2026, 9, 20, 23).millisecondsSinceEpoch;
      final m = <MuestraBat>[
        MuestraBat(base, 10000, 60),
        MuestraBat(base + 12 * 3600000, 10000, 60),
      ];
      final p = calcularDescargaPasiva(m);
      expect(p, hasLength(1));
      expect(p[0].perdidaPct, 0);
      expect(p[0].esRuido, isTrue);
    });

    test('parada corta (< 1 h) no cuenta', () {
      final base = DateTime(2026, 9, 20, 23).millisecondsSinceEpoch;
      final m = <MuestraBat>[
        MuestraBat(base, 10000, 60),
        MuestraBat(base + 30 * 60000, 10000, 59), // -1 % en 30 min
      ];
      expect(calcularDescargaPasiva(m), isEmpty);
    });

    test('cargando a >= 2 A rompe la parada', () {
      final base = DateTime(2026, 9, 20, 23).millisecondsSinceEpoch;
      final m = <MuestraBat>[
        MuestraBat(base, 10000, 60),
        MuestraBat(base + 6 * 3600000, 10000, 58), // -2 % en 6 h
        MuestraBat(base + 6 * 3600000 + 60000, 10000, 58, a: 30), // carga
        MuestraBat(base + 12 * 3600000, 10000, 57), // nueva parada, -1 %
      ];
      final p = calcularDescargaPasiva(m);
      expect(p, hasLength(2));
      expect(p[0].perdidaPct, closeTo(2.0, 1e-9));
      expect(p[0].pctDia, closeTo(8.0, 1e-9)); // 2 % / 6 h
      expect(p[1].perdidaPct, closeTo(1.0, 1e-9));
    });

    test('corriente baja (< 2 A) NO rompe la parada', () {
      final base = DateTime(2026, 9, 20, 23).millisecondsSinceEpoch;
      final m = <MuestraBat>[
        MuestraBat(base, 10000, 60),
        MuestraBat(base + 6 * 3600000, 10000, 58, a: 1), // enchufado a 1 A
        MuestraBat(base + 12 * 3600000, 10000, 57),
      ];
      final p = calcularDescargaPasiva(m);
      expect(p, hasLength(1));
      expect(p[0].perdidaPct, closeTo(3.0, 1e-9));
    });
  });

  group('resumirDescargaPasiva', () {
    test('perdida total / tiempo total (incluye paradas sin perdida)', () {
      final base = DateTime(2026, 9, 20, 23).millisecondsSinceEpoch;
      final m = <MuestraBat>[
        MuestraBat(base, 10000, 60),
        MuestraBat(base + 12 * 3600000, 10000, 58), // -2 % en 12 h
        MuestraBat(base + 12 * 3600000 + 1, 10100, 58), // arranca
        MuestraBat(base + 12 * 3600000 + 2, 10100, 58), // aparca
        MuestraBat(base + 36 * 3600000, 10100, 58), // 24 h sin perder nada
      ];
      final r = resumirDescargaPasiva(calcularDescargaPasiva(m));
      expect(r.numParadas, 2);
      expect(r.horasTotales, closeTo(36.0, 1e-6));
      expect(r.perdidaTotalPct, closeTo(2.0, 1e-9));
      // 2 % en 36 h totales -> 1.333... %/dia
      expect(r.pctDia, closeTo(2.0 / 36.0 * 24.0, 1e-6));
    });

    test('las paradas de ruido cuentan horas pero no perdida', () {
      final base = DateTime(2026, 9, 20, 23).millisecondsSinceEpoch;
      final m = <MuestraBat>[
        MuestraBat(base, 10000, 60),
        MuestraBat(base + 12 * 3600000, 10000, 59.9), // ruido
      ];
      final r = resumirDescargaPasiva(calcularDescargaPasiva(m));
      expect(r.numParadas, 1);
      expect(r.horasTotales, closeTo(12.0, 1e-6));
      expect(r.perdidaTotalPct, 0);
      expect(r.pctDia, 0);
    });

    test('sin paradas no hay cifra', () {
      final r = resumirDescargaPasiva(const []);
      expect(r.pctDia, isNull);
      expect(r.numParadas, 0);
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
