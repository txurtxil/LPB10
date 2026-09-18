// Autonomia real personalizada (R4).
//
// El coche reporta una autonomia con su propio algoritmo (optimista o
// pesimista segun el firmware, y nunca aprende del dueno). LMB10 lleva meses
// guardando consumo real en el agregado diario (daily_stats.dart), asi que
// puede proyectar una autonomia basada en COMO CONDUCE EL USUARIO.
//
// Decisiones:
//  - La media usa los ULTIMOS 30 DIAS si tienen km suficientes (el consumo
//    de enero no debe arrastrar la estimacion de julio). Si no, cae al
//    historico completo: mejor una media vieja que ningun dato.
//  - Los filtros de plausibilidad son los mismos de siempre
//    (DailyStats.kMinAvg/kMaxAvg, km minimos), una sola verdad.
//  - Se trabaja sobre el agregado diario (1 linea por dia) y NO sobre
//    trips.jsonl crudo: la tarjeta se recalcula con cada refresco de estado
//    y parsear 90.000 lineas cada 90 s era justo lo que daily_stats vino a
//    arreglar.
//  - La autonomia al 100% se capa a la fisica del coche (gMaxRangeKm): con
//    pocos datos la media puede salir optimista y prometer km imposibles.
//
// Todo es puro y testeable: nada de IO aqui dentro.

import 'daily_stats.dart';
import 'widget_chart.dart' show gBatteryKwh, gMaxRangeKm;

class RealRangeEstimate {
  /// Consumo base de la estimacion, en % de bateria por 100 km.
  final double pctPer100km;

  /// El mismo consumo en kWh/100 km.
  final double kwh100;

  /// Autonomia real con el SoC actual, en km.
  final int rangeNowKm;

  /// Autonomia real con la bateria al 100%, en km.
  final int rangeFullKm;

  /// true si la media viene de los ultimos 30 dias; false si se uso todo el
  /// historico (poca actividad reciente).
  final bool ventana30d;

  /// Km de datos que sostienen la media (para mostrar la base al usuario).
  final double kmBase;

  const RealRangeEstimate({
    required this.pctPer100km,
    required this.kwh100,
    required this.rangeNowKm,
    required this.rangeFullKm,
    required this.ventana30d,
    required this.kmBase,
  });
}

/// Media de consumo (%/100km) sobre un conjunto de dias, o null si no es
/// creible. Es la misma matematica que
/// TripPointStore.averageConsumptionPercentPer100km (sumar km y caida de SoC
/// y dividir al final), aplicada a los agregados diarios.
double? _mediaPct(Iterable<DayAgg> dias) {
  var km = 0.0;
  var soc = 0.0;
  for (final d in dias) {
    km += d.km;
    soc += d.soc;
  }
  if (km < DailyStats.kMinKm) return null;
  final avg = soc / km * 100.0;
  if (avg < DailyStats.kMinAvg || avg > DailyStats.kMaxAvg) return null;
  return avg;
}

double _kmDe(Iterable<DayAgg> dias) {
  var km = 0.0;
  for (final d in dias) {
    km += d.km;
  }
  return km;
}

/// Km minimos en 30 dias para fiar la estimacion a la ventana reciente.
/// Por debajo, una semana rara (un viaje largo, mucho frio) distorsionaria
/// la estimacion de cada dia.
const double kMinKmVentana30d = 50.0;

/// Calcula la autonomia real. [days] son los agregados diarios (solo filas
/// 'yyyy-MM-dd'; los rollups semanales/mensuales se ignoran), [soc] el
/// porcentaje actual de bateria. Devuelve null si no hay datos creibles.
RealRangeEstimate? computeRealRange(List<DayAgg> days, double? soc,
    {DateTime? now}) {
  final t = now ?? DateTime.now();
  final corte =
      DailyStats.dayKey(t.subtract(const Duration(days: 30)));
  final diarios = days.where((d) => d.d.length == 10).toList();
  final recientes = diarios.where((d) => d.d.compareTo(corte) >= 0).toList();

  double pct;
  bool ventana30d;
  double kmBase;
  final kmRec = _kmDe(recientes);
  final pctRec = kmRec >= kMinKmVentana30d ? _mediaPct(recientes) : null;
  if (pctRec != null) {
    pct = pctRec;
    ventana30d = true;
    kmBase = kmRec;
  } else {
    final pctAll = _mediaPct(diarios);
    if (pctAll == null) return null;
    pct = pctAll;
    ventana30d = false;
    kmBase = _kmDe(diarios);
  }

  final fullKm = (100.0 / pct * 100.0).round().clamp(0, gMaxRangeKm.round());
  final nowKm = soc == null
      ? 0
      : (soc / pct * 100.0).round().clamp(0, gMaxRangeKm.round());

  return RealRangeEstimate(
    pctPer100km: pct,
    kwh100: pct / 100.0 * gBatteryKwh,
    rangeNowKm: nowKm,
    rangeFullKm: fullKm,
    ventana30d: ventana30d,
    kmBase: kmBase,
  );
}

/// Puntos de muestreo totales detras del agregado (para el mensaje de
/// "recopilando datos").
int puntosDe(List<DayAgg> days) {
  var p = 0;
  for (final d in days) {
    if (d.d.length == 10) p += d.pts;
  }
  return p;
}
