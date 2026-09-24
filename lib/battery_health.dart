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

  /// Temperatura de la bateria (senal minBatteryTemp), null si no habia.
  final double? t;

  /// Temperatura exterior (Open-Meteo), null si no habia. Desde v182.
  final double? te;
  const MuestraBat(this.ts, this.km, this.soc, {this.v, this.a, this.t, this.te});
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

  /// Temperatura minima de bateria registrada durante la carga (null si el
  /// historico no la traia).
  final double? tempMin;

  /// Excluida del computo de salud (p. ej. carga con bateria fria: un LFP
  /// frio marca de menos y arrastraria la media a la baja). Se sigue
  /// mostrando en la lista, pero no entra en la cifra principal.
  final bool excluida;

  const EstimacionCarga({
    required this.iniMs,
    required this.finMs,
    required this.socIni,
    required this.socFin,
    required this.energiaKwh,
    required this.capacidadKwh,
    this.tempMin,
    this.excluida = false,
  });

  /// Cuanto tramo de escala cubrio la carga (puntos porcentuales de SoC).
  double get cobertura => socFin - socIni;
}

/// Cifra principal + historico para la pantalla.
class ResumenSalud {
  final double? capacidadKwh;
  final double? dispersionPct;
  final int numEstimaciones;

  /// Cargas excluidas del computo por bateria fria (se muestran aparte).
  final int excluidasFrio;
  final List<EstimacionCarga> estimaciones;

  const ResumenSalud({
    this.capacidadKwh,
    this.dispersionPct,
    this.numEstimaciones = 0,
    this.excluidasFrio = 0,
    this.estimaciones = const [],
  });
}

const double kSocMaxSalud = 95.0;
const double kSocMinGain = 10.0;
const int kMinMinutosCarga = 20;
const double kCapMinPlausible = 20.0;
const double kCapMaxPlausible = 120.0;

/// Corriente minima (A) para que un intervalo cuente como carga. Por debajo
/// un coche enchufado cuenta como parado (mismo umbral que LeapMotor Mate).
const double kMinAmperiosCarga = 2.0;

/// Corte por frio de la salud de la bateria: las cargas cuya temperatura
/// minima de paquete quede por debajo se muestran pero quedan fuera de la
/// estimacion (mismo criterio que Mate, 15 C por defecto).
const double kTempMinSalud = 15.0;

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
  double? tempMin;
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
          tempMin: tempMin,
          excluida: tempMin != null && tempMin! < kTempMinSalud,
        ));
      }
    }
    ini = null;
    energia = 0;
    gain = 0;
    tempMin = null;
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
      for (final tt in [p.t, cur.t]) {
        if (tt != null && (tempMin == null || tt < tempMin!)) tempMin = tt;
      }
      if (potP != null &&
          potC != null &&
          p.a!.abs() >= kMinAmperiosCarga &&
          cur.a!.abs() >= kMinAmperiosCarga) {
        // V x A son vatios: / 1000 para kW, y dtH ya esta en horas -> kWh.
        // Solo cuentan los tramos con corriente por encima del minimo:
        // por debajo el coche enchufado cuenta como parado.
        energia += (potP + potC) / 2.0 / 1000.0 * dtH;
      }
    } else {
      cerrar(cur);
    }
  }
  cerrar(orden.last);
  return out;
}

/// Media ponderada por cobertura de las [ultimas] estimaciones NO excluidas
/// (las frias se quedan fuera) y su dispersion (desviacion tipica relativa,
/// %). null si no hay datos.
ResumenSalud resumirSalud(List<EstimacionCarga> estimaciones,
    {int ultimas = 30}) {
  if (estimaciones.isEmpty) return const ResumenSalud();
  final validas = estimaciones.where((e) => !e.excluida).toList();
  final rec =
      validas.length > ultimas ? validas.sublist(validas.length - ultimas) : validas;
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
    excluidasFrio: estimaciones.where((e) => e.excluida).length,
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

  /// Caidas minimas: ruido del sensor, no una descarga real. En la grafica
  /// van palidas y no cuentan para la cifra principal.
  bool get esRuido => perdidaPct < kRuidoDescargaPasiva;
}

/// Caida minima (puntos de SoC) que se trata como ruido del sensor.
const double kRuidoDescargaPasiva = 0.2;

/// Cifra principal de descarga pasiva, al estilo Mate: la perdida total
/// dividida por el tiempo total aparcado de TODAS las paradas (incluidas
/// las que no perdieron nada), normalizado a %/dia. Mas estable que una
/// mediana por parada cuando hay paradas muy cortas.
class ResumenDescarga {
  final double? pctDia;
  final double perdidaTotalPct;
  final double horasTotales;
  final int numParadas;
  const ResumenDescarga(
      {this.pctDia,
      this.perdidaTotalPct = 0,
      this.horasTotales = 0,
      this.numParadas = 0});
}

/// Detecta paradas (km constante, SoC bajando o quieto) de al menos
/// [minMinutos] y normaliza la perdida a %/dia por parada. Una subida de
/// SoC o un cambio de km cierran la parada: dentro de la parada el coche
/// ni circulo ni cargo.
List<ParadaPerdida> calcularDescargaPasiva(List<MuestraBat> m,
    {int minMinutos = 60}) {
  if (m.length < 2) return const [];
  final orden = List<MuestraBat>.from(m)
    ..sort((a, b) => a.ts.compareTo(b.ts));
  final out = <ParadaPerdida>[];
  int? ini;
  double perdida = 0;
  MuestraBat? prev;

  void cerrarParada() {
    if (ini != null && prev != null) {
      final durMin = (prev.ts - ini!) / 60000.0;
      if (durMin >= minMinutos) {
        out.add(ParadaPerdida(ini!, prev.ts, perdida, perdida / durMin * 1440.0));
      }
    }
    ini = null;
    perdida = 0;
  }

  for (final cur in orden) {
    if (prev != null && cur.ts <= prev.ts) continue;
    final cargando = cur.a != null && cur.a!.abs() >= kMinAmperiosCarga;
    if (prev != null && !cargando && cur.km == prev.km && cur.soc <= prev.soc) {
      ini ??= prev.ts;
      perdida += prev.soc - cur.soc;
    } else {
      cerrarParada();
    }
    prev = cur;
  }
  cerrarParada();
  return out;
}

/// Agregado de las paradas: perdida total / tiempo total, incluidas las
/// paradas que no perdieron nada (aunque no las del nivel del ruido: ahi
/// la lectura no es fiable).
ResumenDescarga resumirDescargaPasiva(List<ParadaPerdida> paradas) {
  if (paradas.isEmpty) return const ResumenDescarga();
  var perdida = 0.0, horas = 0.0;
  for (final p in paradas) {
    horas += (p.finMs - p.iniMs) / 3600000.0;
    if (!p.esRuido) perdida += p.perdidaPct;
  }
  return ResumenDescarga(
    pctDia: horas > 0 ? perdida / horas * 24.0 : null,
    perdidaTotalPct: perdida,
    horasTotales: horas,
    numParadas: paradas.length,
  );
}

/// Mediana de una lista de valores, o null si esta vacia.
double? mediana(List<double> xs) {
  if (xs.isEmpty) return null;
  final s = List<double>.from(xs)..sort();
  final mid = s.length ~/ 2;
  return s.length.isOdd ? s[mid] : (s[mid - 1] + s[mid]) / 2.0;
}
