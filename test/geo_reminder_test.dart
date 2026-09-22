import 'package:flutter_test/flutter_test.dart';
import 'package:lmb10/geo_reminder.dart';

void main() {
  group('evalGeoHome', () {
    test('flanco fuera->dentro con bateria baja y sin enchufar: avisa', () {
      final d = evalGeoHome(
          distM: 120, radiusM: 300, soc: 25, enchufado: false, socUmbral: 30, estabaDentro: false);
      expect(d.dentro, isTrue);
      expect(d.avisar, isTrue);
    });

    test('ya estaba dentro: no repite el aviso', () {
      final d = evalGeoHome(
          distM: 100, radiusM: 300, soc: 20, enchufado: false, socUmbral: 30, estabaDentro: true);
      expect(d.dentro, isTrue);
      expect(d.avisar, isFalse);
    });

    test('enchufado: no hay nada que recordar', () {
      final d = evalGeoHome(
          distM: 100, radiusM: 300, soc: 20, enchufado: true, socUmbral: 30, estabaDentro: false);
      expect(d.avisar, isFalse);
    });

    test('bateria suficiente: no avisa', () {
      final d = evalGeoHome(
          distM: 100, radiusM: 300, soc: 55, enchufado: false, socUmbral: 30, estabaDentro: false);
      expect(d.avisar, isFalse);
    });

    test('fuera de la geocerca: dentro=false y sin aviso', () {
      final d = evalGeoHome(
          distM: 800, radiusM: 300, soc: 20, enchufado: false, socUmbral: 30, estabaDentro: true);
      expect(d.dentro, isFalse);
      expect(d.avisar, isFalse);
    });

    test('sin lectura de posicion: mantiene estado y nunca avisa', () {
      final d1 = evalGeoHome(
          distM: null, radiusM: 300, soc: 20, enchufado: false, socUmbral: 30, estabaDentro: false);
      expect(d1.dentro, isFalse);
      expect(d1.avisar, isFalse);
      final d2 = evalGeoHome(
          distM: null, radiusM: 300, soc: 20, enchufado: false, socUmbral: 30, estabaDentro: true);
      expect(d2.dentro, isTrue);
      expect(d2.avisar, isFalse);
    });

    test('soc desconocido: no avisa', () {
      final d = evalGeoHome(
          distM: 50, radiusM: 300, soc: null, enchufado: false, socUmbral: 30, estabaDentro: false);
      expect(d.avisar, isFalse);
    });

    test('en el borde exacto del radio cuenta como dentro', () {
      final d = evalGeoHome(
          distM: 300, radiusM: 300, soc: 10, enchufado: false, socUmbral: 30, estabaDentro: false);
      expect(d.dentro, isTrue);
      expect(d.avisar, isTrue);
    });
  });
}
