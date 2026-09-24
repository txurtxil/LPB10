// Salud de la bateria (N3 de la hoja de ruta "Modo Dios").
//
// La nube de Leapmotor no publica el SoH. Pero el status trae tension y
// corriente de la bateria (señales 1177/1178), y la app ya guarda el SoC
// con marca de tiempo: de ahi se puede estimar la capacidad util igual que
// hace LeapMotor Mate — la energia medida de cada carga (integral de
// tension x corriente) dividida por el SoC que añadio. Con el tiempo eso
// dibuja la curva de degradacion propia, que nadie (ni la app oficial) da.
//
// Este modulo es el calculo puro (testable, sin IO): la lectura del jsonl,
// el storage y la pantalla viven fuera.
//
// Metodo (mismo criterio que Mate):
//  - Solo muestras con subida de SoC apreciable y energia entrando
//    (tension/corriente presentes). Se usa |V x A|: el signo de la
//    corriente depende de la convencion del coche, y la combinacion
//    "SoC sube + hay potencia" ya identifica la carga.
//  - El SoC contado se CAPA en el 95 %: en una LFP el BMS re-ancla el SoC
//    contado cerca del lleno y esos puntos llegan sin energia asociada.
//  - Cada carga da una estimacion de capacidad; la cifra principal es la
//    media ponderada (por cobertura de escala) de las mas recientes, con
//    su dispersion. Es una estimacion, no una medicion de laboratorio.

/// Una muestra del historico (linea de trips.jsonl).
class MuestraBat {
  final int ts;
  final int km;
  final double soc;
  final double? v;
  final double? a;
  const MuestraBat(this.ts, this.km, this.soc, {this.v, this.a});
}

/// Capacidad estimada a partir de UNA carga.
class EstimacionCarga {
  final int iniMs;
  final int finMs;
  final double socIni;
  final double socFin;

  /// Energia acumulada en la ventana (kWh).
  final double energiaKwh;

  /// energiaKwh / (SoC ganado / 100).
  final double capacidadKwh;

  const EstimacionCarga({
    required this.iniMs,
    required this.finMs,
    required this.socIni,
    required this.socFin,
    required this.energiaKwh,
    required this.capacidadKwh,
  });

  /// Cuanto tramo de escala cubrio la carga (puntos porcentuales de SoC).
  double get cobertura => socFin - socIni;
}

/// Cifra principal + historico para la pantalla.
class ResumenSalud {
  final double? capacidadKwh;
  final double? dispersionPct;
  final int numEstimaciones;
  final List<EstimacionCarga> estimaciones;

  const ResumenSalud({
    this.capacidadKwh,
    this.dispersionPct,
    this.numEstimaciones = 0,
    this.estimaciones = const [],
  });
}

const double kSocMaxSalud = 95.0;
const double kSocMinGain = 10.0;
const int kMinMinutosCarga = 20;
const double kCapMinPlausible = 20.0;
const double kCapMaxPlausible = 120.0;

double _cap95(double soc) => soc > kSocMaxSalud ? kSocMaxSalud : soc;

/// Integra las cargas de una serie cronologica de muestras y devuelve una
/// estimacion de capacidad por cada carga util. Las muestras sin v/a (o con
/// v/a a cero) no aportan energia pero si siguen el SoC: se usan para la
/// cobertura de escala cuando caen dentro de una carga en curso.
List<EstimacionCarga> estimarCapacidades(List<MuestraBat> m) {
  if (m.length < 2) return const [];
  final orden = List<MuestraBat>.from(m)
    ..sort((a, b) => a.ts.compareTo(b.ts));
  final out = <EstimacionCarga>[];

  int? ini;
  double socIni = 0, energia = 0, gain = 0;
  MuestraBat? prev;

  void cerrar(MuestraBat fin) {
    final i = ini;
    if (i == null || prev == null) return;
    final durMin = (prev.ts - i) / 60000.0;
    if (gain >= kSocMinGain &&
        durMin >= kMinMinutosCarga &&
        energia > 0 &&
        gain > 0) {
      final cap = energia / (gain / 100.0);
      if (cap >= kCapMinPlausible && cap <= kCapMaxPlausible) {
        out.add(EstimacionCarga(
          iniMs: i,
          finMs: prev.ts,
          socIni: socIni,
          socFin: _cap95(prev.soc),
          energiaKwh: energia,
          capacidadKwh: cap,
        ));
      }
    }
    ini = null;
    energia = 0;
    gain = 0;
  }

  for (var i = 0; i < orden.length; i++) {
    final cur = orden[i];
    if (prev != null && cur.ts <= prev.ts) continue;
    final p = prev;
    prev = cur;
    if (p == null) continue;

    final dtH = (cur.ts - p.ts) / 3600000.0;
    final potP = (p.v != null && p.a != null) ? (p.v! * p.a!).abs() : null;
    final potC = (cur.v != null && cur.a != null) ? (cur.v! * cur.a!).abs() : null;

    if (cur.soc > p.soc) {
      // SoC subiendo: carga (o regeneracion breve, que los filtros de
      // duracion/escala descartan casi siempre).
      ini ??= p.ts;
      if (ini == p.ts) socIni = _cap95(p.soc);
      gain += _cap95(cur.soc) - _cap95(p.soc);
      if (potP != null && potC != null) {
        // V x A son vatios: / 1000 para kW, y dtH ya esta en horas -> kWh.
        energia += (potP + potC) / 2.0 / 1000.0 * dtH;
      }
    } else {
      cerrar(cur);
    }
  }
  cerrar(orden.last);
  return out;
}

/// Media ponderada por cobertura de las [ultimas] estimaciones y su
/// dispersion (desviacion tipica relativa, %). null si no hay datos.
ResumenSalud resumirSalud(List<EstimacionCarga> estimaciones,
    {int ultimas = 30}) {
  if (estimaciones.isEmpty) return const ResumenSalud();
  final rec =
      estimaciones.length > ultimas ? estimaciones.sublist(estimaciones.length - ultimas) : estimaciones;
  var sumW = 0.0, sumX = 0.0;
  for (final e in rec) {
    final w = e.cobertura > 0 ? e.cobertura : 1.0;
    sumW += w;
    sumX += e.capacidadKwh * w;
  }
  final media = sumW > 0 ? sumX / sumW : null;
  double? disp;
  if (media != null && rec.length > 1) {
    var sumVar = 0.0;
    for (final e in rec) {
      final w = e.cobertura > 0 ? e.cobertura : 1.0;
      final d = e.capacidadKwh - media;
      sumVar += w * d * d;
    }
    disp = sumW > 0 ? (sumVar / sumW) / (media * media) * 100.0 : null;
  }
  return ResumenSalud(
    capacidadKwh: media,
    dispersionPct: disp,
    numEstimaciones: estimaciones.length,
    estimaciones: estimaciones,
  );
}

/// Perdida de carga con el coche aparcado y desenchufado (consumo en
/// reposo: climatizacion en standby, TCU, etc.).
class ParadaPerdida {
  final int iniMs;
  final int finMs;
  final double perdidaPct;
  final double pctDia;
  const ParadaPerdida(this.iniMs, this.finMs, this.perdidaPct, this.pctDia);
}

/// Detecta paradas (km constante, SoC bajando de forma sostenida) y
/// normaliza la perdida a %/dia. Las caidas por debajo de [ruidoMin] se
/// tratan como ruido del sensor.
List<ParadaPerdida> calcularDescargaPasiva(List<MuestraBat> m,
    {int minMinutos = 60, double ruidoMin = 0.2}) {
  if (m.length < 2) return const [];
  final orden = List<MuestraBat>.from(m)
    ..sort((a, b) => a.ts.compareTo(b.ts));
  final out = <ParadaPerdida>[];
  int? ini;
  double perdida = 0;
  MuestraBat? prev;
  for (final cur in orden) {
    if (prev != null && cur.ts <= prev.ts) continue;
    if (prev != null && cur.km == prev.km && cur.soc < prev.soc) {
      ini ??= prev.ts;
      perdida += prev.soc - cur.soc;
    } else {
      if (ini != null && prev != null) {
        final durMin = (prev.ts - ini) / 60000.0;
        if (durMin >= minMinutos && perdida >= ruidoMin) {
          out.add(ParadaPerdida(ini, prev.ts, perdida, perdida / durMin * 1440.0));
        }
      }
      ini = null;
      perdida = 0;
    }
    prev = cur;
  }
  if (ini != null && prev != null) {
    final durMin = (prev.ts - ini) / 60000.0;
    if (durMin >= minMinutos && perdida >= ruidoMin) {
      out.add(ParadaPerdida(ini, prev.ts, perdida, perdida / durMin * 1440.0));
    }
  }
  return out;
}

/// Mediana de una lista de valores, o null si esta vacia.
double? mediana(List<double> xs) {
  if (xs.isEmpty) return null;
  final s = List<double>.from(xs)..sort();
  final mid = s.length ~/ 2;
  return s.length.isOdd ? s[mid] : (s[mid - 1] + s[mid]) / 2.0;
}
