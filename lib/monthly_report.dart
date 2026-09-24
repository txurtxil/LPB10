// Informe mensual automatico (I1 de la hoja de ruta "Modo Dios").
//
// El dia 1 de cada mes LMB10 genera el PDF del mes anterior: km, kWh, euros,
// coste/100 km, CO2 evitado frente a gasolina, ranking de cargas y
// comparativa con el mes anterior. Todo con datos que la app ya recoge.
//
// Este modulo es el calculo puro (testeable, sin IO): fechas, regla de
// "toca generar" y las cuentas del resumen. El PDF, el storage y la
// notificacion viven en monthly_report_pdf.dart y main.dart.

/// Datos agregados de un mes para el informe.
class DatosMes {
  /// Clave 'YYYY-MM'.
  final String mesKey;
  final double km;
  final double kwhConsumidos;
  final double kwhCargados;
  final double euros;
  final int cargas;

  const DatosMes({
    required this.mesKey,
    this.km = 0,
    this.kwhConsumidos = 0,
    this.kwhCargados = 0,
    this.euros = 0,
    this.cargas = 0,
  });

  bool get vacio => km == 0 && kwhConsumidos == 0 && cargas == 0;
}

class ResumenInforme {
  final DatosMes mes;

  /// EUR/100 km, o null si no hay coste disponible.
  final double? coste100km;

  /// kWh/100 km consumidos, o null sin kilometraje.
  final double? consumo100km;

  /// CO2 no emitido frente a un termico equivalente (kg), o null.
  final double? co2EvitadoKg;

  /// Dinero ahorrado frente a gasolina (EUR), o null.
  final double? eurosAhorrados;

  /// Diferencias porcentuales frente al mes anterior (null si no hay).
  final double? difKmPct;
  final double? difCoste100Pct;
  final double? difEurosPct;

  const ResumenInforme({
    required this.mes,
    this.coste100km,
    this.consumo100km,
    this.co2EvitadoKg,
    this.eurosAhorrados,
    this.difKmPct,
    this.difCoste100Pct,
    this.difEurosPct,
  });
}

/// Cuanto CO2 emite un litro de gasolina/gasoleo al quemarse. Es un factor
/// estandar de uso comun (gasolina ~2,31 kg CO2/l).
const double kKgCo2PorLitro = 2.31;

/// Cuentas del informe. Con litros100/precioLitro en 0 (sin configurar el
/// termico de comparacion) las cifras de CO2 y ahorro quedan en null.
ResumenInforme computeResumenInforme({
  required DatosMes mes,
  DatosMes? anterior,
  double litros100 = 0,
  double precioLitro = 0,
}) {
  double? coste100km;
  double? consumo100km;
  if (mes.km > 0) {
    if (mes.euros > 0) coste100km = mes.euros / mes.km * 100.0;
    if (mes.kwhConsumidos > 0) {
      consumo100km = mes.kwhConsumidos / mes.km * 100.0;
    }
  }

  double? co2;
  double? ahorro;
  if (mes.km > 0 && litros100 > 0) {
    final litros = mes.km * litros100 / 100.0;
    co2 = litros * kKgCo2PorLitro;
    if (precioLitro > 0) {
      ahorro = litros * precioLitro - mes.euros;
    }
  }

  double? pct(double a, double b) => b > 0 ? (a - b) / b * 100.0 : null;

  final coste100Ant = (anterior != null && anterior.km > 0 && anterior.euros > 0)
      ? anterior.euros / anterior.km * 100.0
      : null;

  return ResumenInforme(
    mes: mes,
    coste100km: coste100km,
    consumo100km: consumo100km,
    co2EvitadoKg: co2,
    eurosAhorrados: ahorro,
    difKmPct: anterior == null ? null : pct(mes.km, anterior.km),
    difCoste100Pct:
        (coste100km == null || coste100Ant == null) ? null : pct(coste100km, coste100Ant),
    difEurosPct: anterior == null ? null : pct(mes.euros, anterior.euros),
  );
}

/// 'YYYY-MM' de una fecha.
String mesKeyDe(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

/// 'YYYY-MM' del mes anterior a una clave 'YYYY-MM' (con cambio de ano).
String mesAnteriorKey(String mesKey) {
  final y = int.parse(mesKey.substring(0, 4));
  final m = int.parse(mesKey.substring(5, 7));
  final ant = m == 1 ? DateTime(y - 1, 12, 1) : DateTime(y, m - 1, 1);
  return mesKeyDe(ant);
}

/// Regla de disparo del informe mensual: se genera en los primeros DIAS dias
/// del mes, para el mes anterior, y solo una vez (ultimoGenerado guarda la
/// clave del mes YA informado). Asi, si el telefono no hizo ningun ciclo el
/// dia 1, el informe se genera en el primer ciclo disponible de esa semana.
bool debeGenerarInforme({
  required DateTime ahora,
  required String? ultimoGenerado,
  int diasDisparo = 7,
}) {
  if (ahora.day > diasDisparo) return false;
  return ultimoGenerado != mesAnteriorKey(mesKeyDe(ahora));
}
