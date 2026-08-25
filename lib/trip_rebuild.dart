// trip_rebuild.dart
//
// Reconstruye rutas individuales a partir de trips.jsonl, con el mismo
// patron de cache que ChargeRebuild.fromTrips() en daily_stats.dart.
//
// OJO, leccion del 25/08/2026: el odometro (totalMileage) es un ENTERO. Con
// sondeo cada 90s en primer plano, es normal que varias lecturas seguidas
// muestren el mismo km (todavia no se completo el siguiente km entero) y
// luego una sola lectura suba +1. Cortar la ruta en la primera lectura sin
// avance (kmDelta<=0) fragmentaba un trayecto real de varios minutos en
// media docena de "rutas" de 1 km. La correccion: solo se corta si pasa
// kTripMergeGapMs sin ningun avance, no en cuanto aparece UNA lectura sin
// avance.
import 'dart:convert';
import 'daily_stats.dart' show DailyStats;
import 'widget_chart.dart' show gBatteryKwh;

/// Tiempo sin avance de odometro que se considera parada real (fin de ruta).
/// Por debajo de esto, un hueco sin avance se trata como redondeo del
/// odometro entero o una parada breve (semaforo), y NO corta la ruta.
const int kTripMergeGapMs = 20 * 60 * 1000;

/// Cualquier hueco interno mayor que esto, aunque no llegue a cortar la
/// ruta, hace que la duracion se marque como aproximada: pudo haber una
/// parada corta ahi dentro que no vemos con el sondeo que hay.
const int kTripApproxGapMs = 6 * 60 * 1000;

const double kTripMinPct = 8.0; // %/100km imposible por debajo
const double kTripMaxPct = 70.0; // %/100km imposible por encima

class RouteTrip {
  final int startTs;
  final int endTs;
  final double km;
  final double? kwh100; // null = fuera de rango plausible, no se inventa
  final bool aproximada; // hubo un hueco interno > kTripApproxGapMs
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
    int? finProv; // ultimo indice con avance de km dentro del tramo activo
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
      final kmDelta = (pts[i][1] - pts[i - 1][1]).toDouble();
      if (kmDelta > 0) {
        ini ??= i - 1;
        finProv = i;
      } else if (ini != null) {
        // Sin avance en este paso. Solo corta si el hueco SIN AVANCE desde
        // la ultima subida de km supera el margen de fusion.
        final huecoSinAvance = (pts[i][0] - pts[finProv!][0]).toInt();
        if (huecoSinAvance > kTripMergeGapMs) {
          cerrar();
        } else if (huecoSinAvance > maxGapInterno) {
          maxGapInterno = huecoSinAvance;
        }
      }
    }
    cerrar();

    runs.sort((a, b) => b.startTs.compareTo(a.startTs)); // recientes primero
    _cache = runs;
    _cacheLen = len;
    return _cache;
  }

  static RouteTrip _build(List<List<num>> pts, int ini, int fin, int maxGapInterno) {
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
      aproximada: maxGapInterno > kTripApproxGapMs,
      puntos: fin - ini + 1,
    );
  }
}
