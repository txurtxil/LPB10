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
// Tope para RECONSTRUIR una ruta a partir de un unico salto de odometro,
// cuando el movil no sondeo ni una vez durante el trayecto (Android detiene
// la app en segundo plano). Validado el 03/09/2026 con simulacion Python
// sobre 12.907 puntos reales: con 6h se recuperan 109 rutas y el 84% de los
// km del historico, sin alterar ninguna de las 137 que ya salian. Subir a
// 8h o 12h solo anade 1 ruta; a 24h empieza a mezclar trayecto con recarga
// nocturna y el consumo sale absurdo.
const int kTripReconstruibleGapMs = 6 * 60 * 60 * 1000;
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

  /// Ruta deducida de UN salto de odometro, sin ninguna muestra intermedia.
  /// La distancia y el consumo son exactos (salen del odometro y del SOC del
  /// coche), pero no hay recorrido que dibujar ni duracion real: solo se sabe
  /// que el viaje ocurrio en algun momento entre startTs y endTs.
  final bool reconstruida;

  const RouteTrip({
    required this.startTs,
    required this.endTs,
    required this.km,
    required this.kwh100,
    required this.aproximada,
    required this.puntos,
    required this.waypoints,
    this.reconstruida = false,
  });

  Duration get duracion => Duration(milliseconds: endTs - startTs);

  /// Se pide un minimo de 2 puntos GPS para que merezca la pena dibujar
  /// algo: con 1 solo punto no hay linea, solo un marcador suelto.
  ///
  /// Una ruta reconstruida NUNCA dibuja mapa aunque tenga los dos extremos:
  /// unir salida y llegada con una recta seria inventarse el recorrido.
  bool get hasGps => !reconstruida && waypoints.length >= 2;

  /// Codigo del motivo por el que esta ruta no tiene mapa, o null si si lo
  /// tiene. La traduccion se hace en la pantalla, aqui no hay contexto.
  String? get motivoSinMapa {
    if (hasGps) return null;
    if (reconstruida) return 'reconstruida';
    if (waypoints.isEmpty) return 'sin_gps';
    return 'un_punto';
  }
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
      final huecoBruto = pts[i].ts - pts[i - 1].ts;
      // Sin muestras intermedias: interrupcion real de sondeo (TCU
      // dormido, app parada horas o dias). Se cierra y esos km se
      // descartan: no sabemos cuando ocurrieron. Bug reportado: rutas
      // de 46h y 89h.
      if (huecoBruto > kTripMergeGapMs) {
        cerrar();
        // El odometro SI avanzo durante el hueco: hubo un viaje real que el
        // sondeo no llego a ver. Hasta el 03/09/2026 se descartaba entero
        // (este continue se saltaba el kmDelta > 0 de mas abajo) y la ruta
        // desaparecia sin dejar rastro; medido sobre el historico real, asi
        // se perdia el 59% de los km. Ahora se emite como ruta reconstruida.
        if (kmDelta > 0 && huecoBruto <= kTripReconstruibleGapMs) {
          runs.add(_build(pts, i - 1, i, huecoBruto, reconstruida: true));
        }
        continue;
      }
      // Con sondeo continuo de fondo cada 15 min, una parada larga son
      // muchos huecos de 15 min seguidos y ninguno por si solo supera
      // el margen. Lo que hay que mirar es el tiempo acumulado SIN
      // avanzar km desde el ultimo punto real, no el hueco paso a paso.
      // Bug reportado: rutas de 5h o mas con el coche aparcado de por
      // medio.
      if (ini != null) {
        final huecoDesdeUltimoAvance = pts[i].ts - pts[finProv!].ts;
        if (huecoDesdeUltimoAvance > kTripMergeGapMs) {
          cerrar();
        }
      }
      if (kmDelta > 0) {
        ini ??= i - 1;
        finProv = i;
      } else if (ini != null) {
        final hueco = pts[i].ts - pts[finProv!].ts;
        if (hueco > maxGapInterno) maxGapInterno = hueco;
      }
    }
    cerrar();

    runs.sort((a, b) => b.startTs.compareTo(a.startTs));
    _cache = runs;
    _cacheLen = len;
    return _cache;
  }

  static RouteTrip _build(List<_Pt> pts, int ini, int fin, int maxGapInterno,
      {bool reconstruida = false}) {
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
      reconstruida: reconstruida,
    );
  }
}
