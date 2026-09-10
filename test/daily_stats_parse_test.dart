// Regresion del bug de v3.60.138: el parser de trips.jsonl solo aceptaba
// arrays y dejaba la app entera sin precios ("--" en costes, comparativas
// rotas). Con el formato objeto, todos los puntos se descartaban.
import 'package:flutter_test/flutter_test.dart';
import 'package:lmb10/daily_stats.dart';

void main() {
  test('linea formato objeto (el que escribe history_archive)', () {
    final p = DailyStats.puntoDesdeJsonl(
        '{"ts":1757485200000,"km":1200,"soc":55.5}');
    expect(p, isNotNull);
    expect(p![0], 1757485200000);
    expect(p[1], 1200);
    expect(p[2], 55.5);
  });

  test('linea formato array (por si aparece el historico antiguo)', () {
    final p =
        DailyStats.puntoDesdeJsonl('[1757485200000,1200,55.5]');
    expect(p, isNotNull);
    expect(p![0], 1757485200000);
    expect(p[1], 1200);
    expect(p[2], 55.5);
  });

  test('basura, vacio y objetos incompletos dan null', () {
    expect(DailyStats.puntoDesdeJsonl(''), isNull);
    expect(DailyStats.puntoDesdeJsonl('   '), isNull);
    expect(DailyStats.puntoDesdeJsonl('no json'), isNull);
    expect(DailyStats.puntoDesdeJsonl('{"foo":1}'), isNull);
    expect(DailyStats.puntoDesdeJsonl('{"ts":"x","km":1,"soc":2}'), isNull);
  });
}
