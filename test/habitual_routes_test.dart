import 'package:flutter_test/flutter_test.dart';
import 'package:lmb10/habitual_routes.dart';
import 'package:lmb10/trip_rebuild.dart';

RouteTrip viaje(int ts, double km, double? kwh100, List<List<double>> wps,
    {int durMin = 30}) {
  return RouteTrip(
    startTs: ts,
    endTs: ts + durMin * 60000,
    km: km,
    kwh100: kwh100,
    aproximada: false,
    puntos: wps.length,
    waypoints: wps.map((w) => RouteWaypoint(w[0], w[1])).toList(),
  );
}

void main() {
  // Casa y trabajo ficticios separados ~14 km.
  const casa = [43.30, -1.98];
  const trabajo = [43.32, -1.90];
  const playa = [43.38, -1.85];

  test('haversineM: misma coordenada = 0, distancia conocida razonable', () {
    expect(haversineM(43.30, -1.98, 43.30, -1.98), 0);
    // ~1,11 km por cada 0,01 deg de latitud.
    final d = haversineM(43.30, -1.98, 43.31, -1.98);
    expect(d, greaterThan(1000));
    expect(d, lessThan(1200));
  });

  test('dos viajes con mismos extremos forman una ruta habitual', () {
    final trips = [
      viaje(1000, 14.0, 15.0, [casa, trabajo]),
      viaje(2000, 14.2, 16.0, [casa, trabajo]),
    ];
    final r = detectHabitualRoutes(trips);
    expect(r.length, 1);
    expect(r[0].viajes, 2);
    expect(r[0].kmMedio, closeTo(14.1, 0.01));
    expect(r[0].ultimoTs, 2000);
  });

  test('la vuelta (origen/destino invertidos) es la misma ruta', () {
    final trips = [
      viaje(1000, 14.0, 15.0, [casa, trabajo]),
      viaje(2000, 14.1, 14.5, [trabajo, casa]),
    ];
    final r = detectHabitualRoutes(trips);
    expect(r.length, 1);
    expect(r[0].viajes, 2);
  });

  test('extremos lejanos crean rutas distintas', () {
    final trips = [
      viaje(1000, 14.0, 15.0, [casa, trabajo]),
      viaje(2000, 14.1, 15.0, [casa, trabajo]),
      viaje(3000, 10.0, 13.0, [casa, playa]),
      viaje(4000, 10.1, 13.0, [casa, playa]),
    ];
    final r = detectHabitualRoutes(trips);
    expect(r.length, 2);
  });

  test('un viaje suelto no es habitual (minViajes por defecto 2)', () {
    final trips = [
      viaje(1000, 14.0, 15.0, [casa, trabajo]),
    ];
    expect(detectHabitualRoutes(trips), isEmpty);
    expect(detectHabitualRoutes(trips, minViajes: 1).length, 1);
  });

  test('viajes sin 2 waypoints se ignoran', () {
    final trips = [
      viaje(1000, 14.0, 15.0, [casa]),
      viaje(2000, 14.0, 15.0, [casa]),
      viaje(3000, 5.0, 15.0, []),
    ];
    expect(detectHabitualRoutes(trips), isEmpty);
  });

  test('el consumo medio se pondera por km', () {
    final trips = [
      viaje(1000, 10.0, 10.0, [casa, trabajo]), // 10 kWh/100 en 10 km
      viaje(2000, 30.0, 20.0, [casa, trabajo]), // 20 kWh/100 en 30 km
    ];
    final r = detectHabitualRoutes(trips);
    // (10*10 + 20*30) / 40 = 17.5
    expect(r[0].kwh100Medio, closeTo(17.5, 0.01));
  });

  test('viajes sin consumo cuentan como viaje pero no en la media', () {
    final trips = [
      viaje(1000, 14.0, 15.0, [casa, trabajo]),
      viaje(2000, 14.0, null, [casa, trabajo]),
    ];
    final r = detectHabitualRoutes(trips);
    expect(r[0].viajes, 2);
    expect(r[0].kwh100Medio, closeTo(15.0, 0.01));
  });

  test('se ordenan de mas frecuente a menos', () {
    final trips = [
      viaje(1000, 10.0, 13.0, [casa, playa]),
      viaje(2000, 10.0, 13.0, [casa, playa]),
      viaje(3000, 14.0, 15.0, [casa, trabajo]),
      viaje(4000, 14.0, 15.0, [casa, trabajo]),
      viaje(5000, 14.0, 15.0, [casa, trabajo]),
    ];
    final r = detectHabitualRoutes(trips);
    expect(r[0].viajes, 3);
    expect(r[1].viajes, 2);
  });

  test('un viaje a 500 m del extremo sigue siendo la misma ruta', () {
    final trips = [
      viaje(1000, 14.0, 15.0, [casa, trabajo]),
      // ~560 m al norte del trabajo (0,005 deg lat).
      viaje(2000, 14.4, 15.0, [casa, [43.325, -1.90]]),
    ];
    final r = detectHabitualRoutes(trips);
    expect(r.length, 1);
    expect(r[0].viajes, 2);
  });

  test('a mas de 800 m del extremo es otra ruta', () {
    final trips = [
      viaje(1000, 14.0, 15.0, [casa, trabajo]),
      // ~1,1 km al norte del trabajo.
      viaje(2000, 15.0, 15.0, [casa, [43.330, -1.90]]),
    ];
    expect(detectHabitualRoutes(trips), isEmpty);
  });
}
