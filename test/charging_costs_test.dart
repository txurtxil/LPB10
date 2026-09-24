// Tests de costes de carga (clon Mate): deteccion de sesiones,
// clasificacion AC/DC/HPC, energia integrada, coste y agregado mensual.
import 'package:flutter_test/flutter_test.dart';
import 'package:lmb10/battery_health.dart' show MuestraBat;
import 'package:lmb10/charging_costs.dart';

/// Sesion ideal: 9 muestras cada 15 min (2 h) a 400 V y [a] amperios, coche
/// parado en km 10000, SoC 20 -> 80.
List<MuestraBat> sesionIdeal({double a = 10, int base = 0, int km = 10000}) {
  final b = base == 0 ? DateTime(2026, 9, 1, 22).millisecondsSinceEpoch : base;
  final out = <MuestraBat>[];
  for (var i = 0; i <= 8; i++) {
    out.add(MuestraBat(b + i * 15 * 60000, km, 20.0 + i * 7.5, v: 400, a: a));
  }
  return out;
}

void main() {
  group('detectarSesiones', () {
    test('sesion AC ideal: energia = integral V x A', () {
      final s = detectarSesiones(sesionIdeal(a: 10));
      expect(s, hasLength(1));
      // 400 V x 10 A = 4 kW x 2 h = 8 kWh
      expect(s[0].energiaKwh, closeTo(8.0, 1e-6));
      expect(s[0].potMaxKw, closeTo(4.0, 1e-6));
      expect(s[0].tipo, TipoCarga.ac);
      expect(s[0].socIni, 20);
      expect(s[0].socFin, 80);
    });

    test('clasificacion por potencia pico: AC / DC / HPC', () {
      expect(detectarSesiones(sesionIdeal(a: 27.5))[0].tipo, TipoCarga.ac); // 11 kW justo
      expect(detectarSesiones(sesionIdeal(a: 30))[0].tipo, TipoCarga.dc); // 12 kW
      expect(detectarSesiones(sesionIdeal(a: 100))[0].tipo, TipoCarga.dc); // 40 kW
      expect(detectarSesiones(sesionIdeal(a: 300))[0].tipo, TipoCarga.hpc); // 120 kW
    });

    test('un viaje entre dos cargas las separa en dos sesiones', () {
      final m = sesionIdeal(a: 10);
      final fin = m.last.ts;
      // viaje sin telemetria (a null): cierra la primera sesion
      m.add(MuestraBat(fin + 3600000, 10050, 50));
      m.addAll(sesionIdeal(a: 10, base: fin + 7200000, km: 10050));
      final s = detectarSesiones(m);
      expect(s, hasLength(2));
      expect(s[0].energiaKwh, closeTo(8.0, 1e-6));
      expect(s[1].energiaKwh, closeTo(8.0, 1e-6));
    });

    test('corriente por debajo del minimo no es sesion', () {
      expect(detectarSesiones(sesionIdeal(a: 1.5)), isEmpty);
    });

    test('muestra desenchufada a mitad parte la sesion en dos', () {
      final m = <MuestraBat>[];
      final base = DateTime(2026, 9, 1, 22).millisecondsSinceEpoch;
      // 1 h cargando a 4 kW
      for (var i = 0; i <= 4; i++) {
        m.add(MuestraBat(base + i * 15 * 60000, 10000, 20.0 + i * 2, v: 400, a: 10));
      }
      // desconectado 15 min
      m.add(MuestraBat(base + 5 * 15 * 60000, 10000, 28));
      // otra 1 h cargando
      for (var i = 6; i <= 10; i++) {
        m.add(MuestraBat(base + i * 15 * 60000, 10000, 28.0 + (i - 6) * 2, v: 400, a: 10));
      }
      final s = detectarSesiones(m);
      expect(s, hasLength(2));
      expect(s[0].energiaKwh, closeTo(4.0, 1e-6)); // 4 kW x 1 h
      expect(s[1].energiaKwh, closeTo(4.0, 1e-6));
    });

    test('sesion de energia infima se descarta como ruido', () {
      final base = DateTime(2026, 9, 1, 22).millisecondsSinceEpoch;
      // 2 muestras a 1 minuto, 4 kW -> 0.066 kWh < 0.3
      final m = <MuestraBat>[
        MuestraBat(base, 10000, 50, v: 400, a: 10),
        MuestraBat(base + 60000, 10000, 50.1, v: 400, a: 10),
      ];
      expect(detectarSesiones(m), isEmpty);
    });
  });

  group('coste y agregado mensual', () {
    test('coste por sesion segun su tipo y tarifa', () {
      const t = Tarifas(ac: 0.10, dc: 0.35, hpc: 0.55);
      final ac = detectarSesiones(sesionIdeal(a: 10))[0]; // 8 kWh AC
      expect(costeSesion(ac, t), closeTo(0.80, 1e-9));
      final dc = detectarSesiones(sesionIdeal(a: 100))[0]; // 80 kWh DC
      expect(costeSesion(dc, t), closeTo(28.0, 1e-6));
    });

    test('sin tarifa del tipo no hay coste', () {
      const t = Tarifas(dc: 0.35);
      final ac = detectarSesiones(sesionIdeal(a: 10))[0];
      expect(costeSesion(ac, t), isNull);
    });

    test('agregado por mes suma energia por tipo y coste', () {
      final m = sesionIdeal(a: 10); // 8 kWh AC, sept 2026
      final fin = m.last.ts;
      m.add(MuestraBat(fin + 3600000, 10050, 50));
      m.addAll(sesionIdeal(a: 100, base: fin + 7200000, km: 10050)); // 80 kWh DC
      final meses = agregarPorMes(detectarSesiones(m), const Tarifas(ac: 0.10, dc: 0.35));
      expect(meses, hasLength(1));
      final mes = meses['2026-09']!;
      expect(mes.sesiones, 2);
      expect(mes.kwhAc, closeTo(8.0, 1e-6));
      expect(mes.kwhDc, closeTo(80.0, 1e-6));
      expect(mes.coste, closeTo(0.80 + 28.0, 1e-6));
    });
  });
}
