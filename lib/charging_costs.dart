// Costes de carga (clon de LeapMotor Mate): detecta las sesiones de carga
// del historico local (trips.jsonl), las clasifica en AC / DC / HPC por la
// potencia pico y les aplica las tarifas del usuario para dar el coste por
// sesion y los totales del mes.
//
// La energia es la misma integral de tension x corriente que usa la salud
// de la bateria: es la que ENTRA al paquete. La energia de red (la que
// factura el cargador) es algo mayor por las perdidas de conversion; se
// indica en la pantalla.
//
// Modulo puro (testable, sin IO): las tarifas se guardan fuera.

import 'battery_health.dart' show MuestraBat, kMinAmperiosCarga;

/// Tipo de carga por potencia pico (mismos cortes que Mate).
enum TipoCarga { ac, dc, hpc }

/// Potencia pico maxima para considerar una sesion AC (kW).
const double kKwAcMax = 11.0;

/// Potencia pico a partir de la cual una sesion DC rapida cuenta como HPC.
const double kKwHpcMin = 100.0;

/// Energia minima de una sesion para no ser ruido (kWh).
const double kMinKwhSesion = 0.3;

/// Una sesion de carga detectada en el historico.
class SesionCarga {
  final int iniMs;
  final int finMs;
  final double socIni;
  final double socFin;

  /// Energia integrada V x A durante la sesion (kWh, al paquete).
  final double energiaKwh;

  /// Potencia pico de la sesion (kW).
  final double potMaxKw;
  final TipoCarga tipo;

  const SesionCarga({
    required this.iniMs,
    required this.finMs,
    required this.socIni,
    required this.socFin,
    required this.energiaKwh,
    required this.potMaxKw,
    required this.tipo,
  });
}

/// Tarifas del usuario en EUR/kWh; null = sin configurar (no hay coste).
class Tarifas {
  final double? ac;
  final double? dc;
  final double? hpc;
  const Tarifas({this.ac, this.dc, this.hpc});

  double? para(TipoCarga t) =>
      t == TipoCarga.ac ? ac : (t == TipoCarga.dc ? dc : hpc);
}

TipoCarga clasificar(double potMaxKw) =>
    potMaxKw <= kKwAcMax ? TipoCarga.ac : (potMaxKw < kKwHpcMin ? TipoCarga.dc : TipoCarga.hpc);

/// Coste de una sesion con las tarifas dadas, o null si la tarifa de su
/// tipo no esta configurada.
double? costeSesion(SesionCarga s, Tarifas t) {
  final tarifa = t.para(s.tipo);
  return tarifa == null ? null : s.energiaKwh * tarifa;
}

/// Detecta sesiones de carga: tramos consecutivos con corriente por encima
/// del minimo (>= 2 A, como Mate) y el coche parado (km constante). Una
/// muestra sin corriente, por debajo del minimo, o un cambio de km, cierra
/// la sesion. Se descartan las de energia infima (ruido).
List<SesionCarga> detectarSesiones(List<MuestraBat> m) {
  if (m.length < 2) return const [];
  final orden = List<MuestraBat>.from(m)
    ..sort((a, b) => a.ts.compareTo(b.ts));
  final out = <SesionCarga>[];

  List<MuestraBat> sesion = [];

  bool cargando(MuestraBat s) => s.a != null && s.a!.abs() >= kMinAmperiosCarga;

  void cerrar() {
    if (sesion.length >= 2) {
      var energia = 0.0;
      var potMax = 0.0;
      for (var i = 1; i < sesion.length; i++) {
        final p = sesion[i - 1], c = sesion[i];
        if (p.v != null && p.a != null && c.v != null && c.a != null) {
          final potP = (p.v! * p.a!).abs();
          final potC = (c.v! * c.a!).abs();
          energia += (potP + potC) / 2.0 / 1000.0 * ((c.ts - p.ts) / 3600000.0);
          if (potP / 1000.0 > potMax) potMax = potP / 1000.0;
          if (potC / 1000.0 > potMax) potMax = potC / 1000.0;
        }
      }
      if (energia >= kMinKwhSesion) {
        out.add(SesionCarga(
          iniMs: sesion.first.ts,
          finMs: sesion.last.ts,
          socIni: sesion.first.soc,
          socFin: sesion.last.soc,
          energiaKwh: energia,
          potMaxKw: potMax,
          tipo: clasificar(potMax),
        ));
      }
    }
    sesion = [];
  }

  MuestraBat? prev;
  for (final cur in orden) {
    if (prev != null && cur.ts <= prev.ts) continue;
    if (cargando(cur) && (prev == null || sesion.isEmpty || (cargando(prev) && cur.km == prev.km))) {
      sesion.add(cur);
    } else {
      cerrar();
    }
    prev = cur;
  }
  cerrar();
  return out;
}

/// Puntos (timestamp, kW) de la curva de potencia de una sesion, para la
/// grafica de detalle. Solo muestras con v y a presentes.
List<(int, double)> curvaPotencia(List<MuestraBat> m, int iniMs, int finMs) {
  final out = <(int, double)>[];
  for (final s in m) {
    if (s.ts < iniMs || s.ts > finMs) continue;
    if (s.v == null || s.a == null) continue;
    out.add((s.ts, (s.v! * s.a!).abs() / 1000.0));
  }
  out.sort((a, b) => a.$1.compareTo(b.$1));
  return out;
}

/// Eficiencia real de una carga: lo que entro al paquete entre lo que
/// marco el cargador (%). null si no se anoto el dato del cargador.
double? eficienciaReal(double kwhPaquete, double? kwhCargador) =>
    (kwhCargador == null || kwhCargador <= 0)
        ? null
        : kwhPaquete / kwhCargador * 100.0;

/// Totales de un mes: energia por tipo y coste (solo de las sesiones cuya
/// tarifa esta configurada; null si no hubo ninguna con tarifa).
class MesCarga {
  double kwhAc = 0, kwhDc = 0, kwhHpc = 0;
  double? coste;
  int sesiones = 0;
}

/// Agrupa las sesiones por mes ('2026-09' -> totales).
Map<String, MesCarga> agregarPorMes(List<SesionCarga> sesiones, Tarifas t) {
  final out = <String, MesCarga>{};
  for (final s in sesiones) {
    final d = DateTime.fromMillisecondsSinceEpoch(s.finMs);
    final clave = '${d.year}-${d.month.toString().padLeft(2, '0')}';
    final mes = out.putIfAbsent(clave, () => MesCarga());
    mes.sesiones++;
    if (s.tipo == TipoCarga.ac) {
      mes.kwhAc += s.energiaKwh;
    } else if (s.tipo == TipoCarga.dc) {
      mes.kwhDc += s.energiaKwh;
    } else {
      mes.kwhHpc += s.energiaKwh;
    }
    final c = costeSesion(s, t);
    if (c != null) mes.coste = (mes.coste ?? 0) + c;
  }
  return out;
}
