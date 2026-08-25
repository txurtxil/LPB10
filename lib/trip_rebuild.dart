// trip_rebuild.dart
//
// Reconstruye rutas individuales a partir de trips.jsonl, con el mismo
// patron de cache que ChargeRebuild.fromTrips() en daily_stats.dart.
//
// lat/lon son OPCIONALES en cada punto: las lecturas guardadas antes de
// anadir captura de GPS no los tienen, y esas rutas simplemente saldran con
// hasGps=false (sin boton de mapa), nunca con coordenadas inventadas.
//
// OJO, leccion del 25/08/2026: el odometro (totalMileage) es un ENTERO. Con
// sondeo cada 90s en primer plano, varias lecturas seguidas pueden mostrar
// el mismo km antes de que el contador suba +1. Solo se corta una ruta si
// pasan kTripMergeGapMs SIN NINGUN avance, no en la primera lectura sin
// avance.
import 'dart:convert';
import 'daily_stats.dart' show DailyStats;
import 'widget_chart.dart' show gBatteryKwh;

const int kTripMergeGapMs = 20 * 60 * 1000;
const int kTripApproxGapMs = 6 * 60 * 1000;
const double kTripMinPct = 8.0;
const double kTripMaxPct = 70.0;

class _Pt {
  final int ts;
  final int km;
  final double soc;
  final double? lat;
  final double? lon;
  const _Pt(this.ts, this.km, this.soc, this.lat, this.lon);
}

class RouteWaypoint {
  final double lat;
  final double lon;
  const RouteWaypoint(this.lat, this.lon);
}

class RouteTrip {
  final int startTs;
  final int endTs;
  final double km;
  final double? kwh100;
  final bool aproximada;
  final int puntos;
  final List<RouteWaypoint> waypoints;

  const RouteTrip({
    required this.startTs,
    required this.endTs,
    required this.km,
    required this.kwh100,
    required this.aproximada,
    required this.puntos,
    required this.waypoints,
  });

  Duration get duracion => Duration(milliseconds: endTs - startTs);

  /// Se pide un minimo de 2 puntos GPS para que merezca la pena dibujar
  /// algo: con 1 solo punto no hay linea, solo un marcador suelto.
  bool get hasGps => waypoints.length >= 2;
}

class TripRebuild {
  static int _cacheLen = -1;
  static List<RouteTrip> _cache = <RouteTrip>[];

  static Future<List<RouteTrip>> fromTrips() async {
    final f = await DailyStats.tripsFile();
    if (!await f.exists()) return <RouteTrip>[];
    final len = await f.length();
    if (len == _cacheLen) return _cache;

    final seen = <String>{};
    final pts = <_Pt>[];
    for (final line in await f.readAsLines()) {
      final t = line.trim();
      if (t.isEmpty) continue;
      try {
        final m = Map<String, dynamic>.from(json.decode(t) as Map);
        final ts = m['ts'];
        final km = m['km'];
        final soc = m['soc'];
        if (ts is! int || km is! int || soc is! num) continue;
        final k = '$ts:$km:$soc';
        if (!seen.add(k)) continue;
        final lat = (m['lat'] as num?)?.toDouble();
        final lon = (m['lon'] as num?)?.toDouble();
        pts.add(_Pt(ts, km, soc.toDouble(), lat, lon));
      } catch (_) {}
    }
    pts.sort((a, b) => a.ts.compareTo(b.ts));

    final runs = <RouteTrip>[];
    int? ini;
    int? finProv;
    int maxGapInterno = 0;

    void cerrar() {
      if (ini != null && finProv != null) {
        runs.add(_build(pts, ini!, finProv!, maxGapInterno));
      }
      ini = null;
      finProv = null;
      maxGapInterno = 0;
    }

    for (var i = 1; i < pts.length; i++) {
      final kmDelta = (pts[i].km - pts[i - 1].km).toDouble();
      if (kmDelta > 0) {
        ini ??= i - 1;
        finProv = i;
      } else if (ini != null) {
        final huecoSinAvance = pts[i].ts - pts[finProv!].ts;
        if (huecoSinAvance > kTripMergeGapMs) {
          cerrar();
        } else if (huecoSinAvance > maxGapInterno) {
          maxGapInterno = huecoSinAvance;
        }
      }
    }
    cerrar();

    runs.sort((a, b) => b.startTs.compareTo(a.startTs));
    _cache = runs;
    _cacheLen = len;
    return _cache;
  }

  static RouteTrip _build(List<_Pt> pts, int ini, int fin, int maxGapInterno) {
    final kmTotal = (pts[fin].km - pts[ini].km).toDouble();
    var socDrop = 0.0;
    for (var i = ini + 1; i <= fin; i++) {
      socDrop += pts[i - 1].soc - pts[i].soc;
    }
    double? kwh100;
    if (kmTotal > 0 && socDrop > 0) {
      final pct = socDrop / kmTotal * 100;
      if (pct >= kTripMinPct && pct <= kTripMaxPct) {
        kwh100 = socDrop * gBatteryKwh / kmTotal;
      }
    }
    final waypoints = <RouteWaypoint>[];
    for (var i = ini; i <= fin; i++) {
      final la = pts[i].lat;
      final lo = pts[i].lon;
      if (la != null && lo != null) waypoints.add(RouteWaypoint(la, lo));
    }
    return RouteTrip(
      startTs: pts[ini].ts,
      endTs: pts[fin].ts,
      km: kmTotal,
      kwh100: kwh100,
      aproximada: maxGapInterno > kTripApproxGapMs,
      puntos: fin - ini + 1,
      waypoints: waypoints,
    );
  }
}
