// Consumo segun temperatura (clon de LeapMotor Mate): cada tramo de
// conduccion del historico (km avanzando, SoC bajando) da un punto
// (temperatura media del tramo, consumo en % de bateria por 100 km). La
// nube no da kWh consumidos por tramo, pero el %/100 km dibuja igualmente
// la curva frio/calor.
//
// Temperatura del punto: la exterior (Open-Meteo, 'te') si la hay; si no,
// la del paquete ('t'). Los tramos sin ninguna temperatura no puntuan.
//
// Modulo puro (testable, sin IO).

import 'battery_health.dart' show MuestraBat;

/// Un punto de la nube consumo-temperatura.
class PuntoConsumo {
  /// Temperatura media del tramo (exterior si hay, del paquete si no).
  final double temp;

  /// Consumo del tramo en puntos de SoC por 100 km.
  final double pct100km;

  /// Longitud del tramo (km).
  final double km;
  const PuntoConsumo(this.temp, this.pct100km, this.km);
}

/// Filtros fisicos: un tramo debe recorrer al menos 2 km y el consumo debe
/// ser plausible (2..45 %/100 km; fuera de ahi es ruido de SoC/km).
const double kMinKmTramo = 2.0;
const double kMinPct100 = 2.0;
const double kMaxPct100 = 45.0;

/// Extrae los puntos consumo-temperatura de una serie cronologica. Una
/// subida de SoC (carga o regeneracion fuerte) o km quieto cierran el
/// tramo en curso.
List<PuntoConsumo> consumoVsTemp(List<MuestraBat> m) {
  if (m.length < 2) return const [];
  final orden = List<MuestraBat>.from(m)
    ..sort((a, b) => a.ts.compareTo(b.ts));
  final out = <PuntoConsumo>[];

  int? kmIni;
  double? socIni;
  var sumT = 0.0;
  var numT = 0;

  void acumTemp(MuestraBat s) {
    final t = s.te ?? s.t;
    if (t != null) {
      sumT += t;
      numT++;
    }
  }

  void cerrar(MuestraBat fin) {
    final ki = kmIni;
    final si = socIni;
    if (ki != null && si != null && numT > 0) {
      final kmDelta = (fin.km - ki).toDouble();
      final socDrop = si - fin.soc;
      if (kmDelta >= kMinKmTramo && socDrop > 0) {
        final pct = socDrop / kmDelta * 100.0;
        if (pct >= kMinPct100 && pct <= kMaxPct100) {
          out.add(PuntoConsumo(sumT / numT, pct, kmDelta));
        }
      }
    }
    kmIni = null;
    socIni = null;
    sumT = 0;
    numT = 0;
  }

  MuestraBat? prev;
  for (final cur in orden) {
    if (prev != null && cur.ts <= prev.ts) continue;
    final p = prev;
    prev = cur;
    if (p == null) continue;
    if (cur.km > p.km && cur.soc < p.soc) {
      kmIni ??= p.km;
      socIni ??= p.soc;
      // Solo puntuan las temperaturas de las lecturas DENTRO del tramo: la
      // lectura ancla (p) es del final del tramo anterior o de la parada.
      acumTemp(cur);
    } else {
      cerrar(p);
    }
  }
  final ultima = orden.last;
  cerrar(ultima);
  return out;
}
