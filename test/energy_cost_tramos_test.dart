// Primer test del repo: nucleo de la atribucion de coste por tramos.
import 'package:flutter_test/flutter_test.dart';
import 'package:lmb10/energy_cost.dart';

void main() {
  String diaDe(int tsMs) =>
      DateTime.fromMillisecondsSinceEpoch(tsMs, isUtc: true)
          .toIso8601String()
          .substring(0, 10);
  int ts(int dia, int hora) =>
      DateTime.utc(2026, 9, dia, hora).millisecondsSinceEpoch;

  test('dos cargas el mismo dia a distinto precio: cada una precia su tramo',
      () {
    final tramos = <List<double>>[
      [ts(10, 8).toDouble(), 0.15],
      [ts(10, 18).toDouble(), 0.50],
    ];
    final segs = <List<double>>[
      [ts(10, 10).toDouble(), 10.0],
      [ts(10, 19).toDouble(), 5.0],
      [ts(11, 9).toDouble(), 8.0],
    ];
    final e = eurosPorTramoCore(tramos, segs, null, 50.0, diaDe);
    expect(e['2026-09-10'], closeTo(5.0 * 0.15 + 2.5 * 0.50, 1e-9));
    expect(e['2026-09-11'], closeTo(4.0 * 0.50, 1e-9));
  });

  test('consumo anterior a la primera carga: precio fijo', () {
    final e = eurosPorTramoCore(
        [[ts(10, 8).toDouble(), 0.15]], [[ts(9, 12).toDouble(), 4.0]],
        0.20, 50.0, diaDe);
    expect(e['2026-09-09'], closeTo(2.0 * 0.20, 1e-9));
  });

  test('sin precio fijo y sin carga previa: ese consumo no se cobra', () {
    final e = eurosPorTramoCore(
        [[ts(10, 8).toDouble(), 0.15]], [[ts(9, 12).toDouble(), 4.0]],
        null, 50.0, diaDe);
    expect(e['2026-09-09'], isNull);
  });

  test('sin cargas pero con precio fijo: todo al precio fijo', () {
    final e = eurosPorTramoCore(const [], [[ts(11, 9).toDouble(), 8.0]],
        0.20, 50.0, diaDe);
    expect(e['2026-09-11'], closeTo(4.0 * 0.20, 1e-9));
  });
}
