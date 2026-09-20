// Deteccion de rutas habituales (R1 de la hoja de ruta "Modo Dios").
//
// El historico de viajes (TripRebuild) lleva meses guardando origen y destino
// GPS de cada trayecto. Aqui se agrupan por proximidad para responder a
// "cuales son MIS rutas de siempre y cuanto me cuestan": Casa->Trabajo,
// casa de los suegros, la compra del sabado...
//
// Decisiones:
//  - Clustering greedy por extremos: dos viajes son la misma ruta si origen
//    Y destino caen a menos de [radioM] de los extremos del grupo. Se acepta
//    tambien la orientacion inversa (Casa->Trabajo y Trabajo->Casa son el
//    mismo trayecto habitual).
//  - Sin geocodificacion: no hay red ni libreria offline de nombres de
//    calles, asi que las rutas se presentan como "Ruta 1, Ruta 2..." con su
//    distancia media, que es como el usuario las reconoce.
//  - El consumo medio se pondera por km (un viaje de 40 km pesa mas que uno
//    de 3 km). Los viajes sin kwh100 (tramos dudosos) no contaminan la media
//    pero si cuentan como viaje.
//  - Todo puro y testeable: cero IO aqui dentro.

import 'dart:math' as math;

import 'trip_rebuild.dart';

/// Distancia haversine en metros entre dos coordenadas.
double haversineM(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0; // radio medio de la Tierra, m
  double rad(double g) => g * math.pi / 180.0;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) *
          math.sin(dLon / 2) * math.sin(dLon / 2);
  return 2 * r * math.asin(math.sqrt(a));
}

class HabitualRoute {
  /// Extremos del grupo (del primer viaje que lo creo). Como se acepta la
  /// orientacion inversa, 'a' y 'b' no significan origen/destino: son los
  /// dos puntos del trayecto.
  final RouteWaypoint a;
  final RouteWaypoint b;

  int viajes = 0;
  double kmTotal = 0;
  int ultimoTs = 0;

  /// Media de consumo ponderada por km: suma de (kwh100 * km) y de los km
  /// que aportaron consumo. Los viajes sin kwh100 no entran en la media.
  double _kwhKmPeso = 0;
  double _kmConConsumo = 0;
  int _durTotalMs = 0;

  /// Ultimo viaje del grupo con GPS suficiente para dibujar el mapa.
  RouteTrip? ultimoConGps;

  HabitualRoute(this.a, this.b);

  double get kmMedio => viajes > 0 ? kmTotal / viajes : 0;
  double? get kwh100Medio => _kmConConsumo > 0 ? _kwhKmPeso / _kmConConsumo : null;
  Duration get duracionMedia =>
      Duration(milliseconds: viajes > 0 ? _durTotalMs ~/ viajes : 0);

  void add(RouteTrip t) {
    viajes += 1;
    kmTotal += t.km;
    _durTotalMs += t.duracion.inMilliseconds;
    if (t.kwh100 != null && t.kwh100! > 0) {
      _kwhKmPeso += t.kwh100! * t.km;
      _kmConConsumo += t.km;
    }
    if (t.startTs >= ultimoTs) {
      ultimoTs = t.startTs;
      if (t.hasGps) ultimoConGps = t;
    }
  }

  bool coincide(RouteWaypoint o, RouteWaypoint d, double radioM) {
    final directo = haversineM(o.lat, o.lon, a.lat, a.lon) <= radioM &&
        haversineM(d.lat, d.lon, b.lat, b.lon) <= radioM;
    final inverso = haversineM(o.lat, o.lon, b.lat, b.lon) <= radioM &&
        haversineM(d.lat, d.lon, a.lat, a.lon) <= radioM;
    return directo || inverso;
  }
}

/// Agrupa [trips] en rutas habituales. Solo entran viajes con los dos
/// extremos conocidos (2+ waypoints); los sin GPS no se pueden clasificar.
/// Se devuelven solo grupos con [minViajes] o mas viajes, ordenados de mas
/// frecuente a menos.
List<HabitualRoute> detectHabitualRoutes(List<RouteTrip> trips,
    {double radioM = 800, int minViajes = 2}) {
  final ordenados = List<RouteTrip>.from(trips)
    ..sort((x, y) => x.startTs.compareTo(y.startTs));
  final clusters = <HabitualRoute>[];
  for (final t in ordenados) {
    if (t.waypoints.length < 2) continue;
    final o = t.waypoints.first;
    final d = t.waypoints.last;
    HabitualRoute? match;
    for (final c in clusters) {
      if (c.coincide(o, d, radioM)) {
        match = c;
        break;
      }
    }
    (match ?? (() {
      final c = HabitualRoute(o, d);
      clusters.add(c);
      return c;
    })())
        .add(t);
  }
  final out = clusters.where((c) => c.viajes >= minViajes).toList()
    ..sort((x, y) => y.viajes.compareTo(x.viajes));
  return out;
}
