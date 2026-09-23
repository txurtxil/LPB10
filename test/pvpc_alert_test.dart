// Tests del aviso de carga barata de manana (N2).
import 'package:flutter_test/flutter_test.dart';
import 'package:lmb10/pvpc_alert.dart';

List<double> horasBase() => List<double>.filled(24, 0.15);

void main() {
  group('evalPvpcAlert', () {
    test('sin precios de manana no avisa (aun no publicados)', () {
      expect(
        evalPvpcAlert(
          fechaManana: '2026-09-25',
          horasManana: null,
          soc: 50,
          enchufado: true,
          cargando: false,
          yaAvisada: null,
          dtoPct: 0,
        ),
        isNull,
      );
    });

    test('lista vacia (cache negativo) no avisa', () {
      expect(
        evalPvpcAlert(
          fechaManana: '2026-09-25',
          horasManana: const [],
          soc: 50,
          enchufado: true,
          cargando: false,
          yaAvisada: null,
          dtoPct: 0,
        ),
        isNull,
      );
    });

    test('no avisa dos veces el mismo dia', () {
      final d = evalPvpcAlert(
        fechaManana: '2026-09-25',
        horasManana: horasBase(),
        soc: 50,
        enchufado: true,
        cargando: false,
        yaAvisada: '2026-09-25',
        dtoPct: 0,
      );
      expect(d, isNull);
    });

    test('no avisa si no esta enchufado', () {
      expect(
        evalPvpcAlert(
          fechaManana: '2026-09-25',
          horasManana: horasBase(),
          soc: 50,
          enchufado: false,
          cargando: false,
          yaAvisada: null,
          dtoPct: 0,
        ),
        isNull,
      );
    });

    test('no avisa si ya esta cargando ahora', () {
      expect(
        evalPvpcAlert(
          fechaManana: '2026-09-25',
          horasManana: horasBase(),
          soc: 50,
          enchufado: true,
          cargando: true,
          yaAvisada: null,
          dtoPct: 0,
        ),
        isNull,
      );
    });

    test('no avisa con bateria alta (por encima del umbral)', () {
      expect(
        evalPvpcAlert(
          fechaManana: '2026-09-25',
          horasManana: horasBase(),
          soc: 81,
          enchufado: true,
          cargando: false,
          yaAvisada: null,
          dtoPct: 0,
        ),
        isNull,
      );
    });

    test('no avisa sin SoC conocido', () {
      expect(
        evalPvpcAlert(
          fechaManana: '2026-09-25',
          horasManana: horasBase(),
          soc: null,
          enchufado: true,
          cargando: false,
          yaAvisada: null,
          dtoPct: 0,
        ),
        isNull,
      );
    });

    test('si avisa: elige la ventana contigua mas barata y su precio medio', () {
      final horas = horasBase();
      horas[3] = 0.04;
      horas[4] = 0.05;
      horas[5] = 0.06;
      final d = evalPvpcAlert(
        fechaManana: '2026-09-25',
        horasManana: horas,
        soc: 45,
        enchufado: true,
        cargando: false,
        yaAvisada: '2026-09-24',
        dtoPct: 0,
      );
      expect(d, isNotNull);
      expect(d!.horaIni, 3);
      expect(d.horaFin, 6);
      expect(d.precioMedio, closeTo(0.05, 1e-9));
      expect(d.fecha, '2026-09-25');
    });

    test('el umbral es inclusivo: avisa justo en el 80%', () {
      final d = evalPvpcAlert(
        fechaManana: '2026-09-25',
        horasManana: horasBase(),
        soc: 80,
        enchufado: true,
        cargando: false,
        yaAvisada: null,
        dtoPct: 0,
      );
      expect(d, isNotNull);
    });

    test('aplica el descuento configurado al precio medio', () {
      final d = evalPvpcAlert(
        fechaManana: '2026-09-25',
        horasManana: horasBase(),
        soc: 50,
        enchufado: true,
        cargando: false,
        yaAvisada: null,
        dtoPct: 25,
      );
      expect(d, isNotNull);
      expect(d!.precioMedio, closeTo(0.15 * 0.75, 1e-9));
    });

    test('la ventana elegida no cruza medianoche', () {
      final horas = horasBase();
      horas[22] = 0.01;
      horas[23] = 0.01;
      final d = evalPvpcAlert(
        fechaManana: '2026-09-25',
        horasManana: horas,
        soc: 50,
        enchufado: true,
        cargando: false,
        yaAvisada: null,
        dtoPct: 0,
        duracionHoras: 3,
      );
      expect(d, isNotNull);
      expect(d!.horaFin, lessThanOrEqualTo(24));
    });
  });

  group('formatoHoraPvpc', () {
    test('rellena con cero a la izquierda', () {
      expect(formatoHoraPvpc(3), '03:00');
      expect(formatoHoraPvpc(23), '23:00');
    });
  });
}
