// trip_rebuild.dart
//
// Reconstruye rutas individuales a partir de trips.jsonl, con el mismo
// patron que ChargeRebuild.fromTrips() en daily_stats.dart: cache por
// longitud de fichero (no se reparsea si no ha crecido), lectura completa
// solo cuando hace falta.
//
// Una "ruta" es una cadena de puntos consecutivos con kmDelta > 0. Se corta
// en el primer punto con kmDelta <= 0 (coche parado o cargando). El
// muestreo es cada 90s en primer plano y cada 15 min en segundo plano (limite
// de Android), asi que una ruta con la app dormida puede tener solo el punto
// de salida y el de llegada: la duracion en ese caso es un margen, no un
// cronometro. Cualquier hueco interno > 20 min se marca como aproximado en
// vez de presentarse como preciso.
import 'dart:convert';
import 'daily_stats.dart' show DailyStats;
import 'widget_chart.dart' show gBatteryKwh;

const int kTripLongGapMs = 20 * 60 * 1000;
const double kTripMinPct = 8.0; // %/100km imposible por debajo
const double kTripMaxPct = 70.0; // %/100km imposible por encima

class RouteTrip {
  final int startTs;
  final int endTs;
  final double km;
  final double? kwh100; // null = fuera de rango plausible, no se inventa
  final bool aproximada; // hubo un hueco interno > kTripLongGapMs
  final int puntos;

  const RouteTrip({
    required this.startTs,
    required this.endTs,
    required this.km,
    required this.kwh100,
    required this.aproximada,
    required this.puntos,
  });

  Duration get duracion => Duration(milliseconds: endTs - startTs);
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
    final pts = <List<num>>[]; // [ts, km, soc]
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
        pts.add([ts, km, soc.toDouble()]);
      } catch (_) {}
    }
    pts.sort((a, b) => (a[0] as int).compareTo(b[0] as int));

    final runs = <RouteTrip>[];
    int? ini;
    int maxGap = 0;
    for (var i = 1; i < pts.length; i++) {
      final kmDelta = (pts[i][1] - pts[i - 1][1]).toDouble();
      final gap = (pts[i][0] - pts[i - 1][0]).toInt();
      if (kmDelta > 0) {
        ini ??= i - 1;
        if (gap > maxGap) maxGap = gap;
      } else if (ini != null) {
        runs.add(_build(pts, ini, i - 1, maxGap));
        ini = null;
        maxGap = 0;
      }
    }
    if (ini != null) {
      runs.add(_build(pts, ini, pts.length - 1, maxGap));
    }

    runs.sort((a, b) => b.startTs.compareTo(a.startTs)); // recientes primero
    _cache = runs;
    _cacheLen = len;
    return _cache;
  }

  static RouteTrip _build(List<List<num>> pts, int ini, int fin, int maxGap) {
    final kmTotal = (pts[fin][1] - pts[ini][1]).toDouble();
    var socDrop = 0.0;
    for (var i = ini + 1; i <= fin; i++) {
      socDrop += (pts[i - 1][2] - pts[i][2]).toDouble();
    }
    double? kwh100;
    if (kmTotal > 0 && socDrop > 0) {
      final pct = socDrop / kmTotal * 100;
      if (pct >= kTripMinPct && pct <= kTripMaxPct) {
        kwh100 = socDrop * gBatteryKwh / kmTotal;
      }
    }
    return RouteTrip(
      startTs: pts[ini][0].toInt(),
      endTs: pts[fin][0].toInt(),
      km: kmTotal,
      kwh100: kwh100,
      aproximada: maxGap > kTripLongGapMs,
      puntos: fin - ini + 1,
    );
  }
}
