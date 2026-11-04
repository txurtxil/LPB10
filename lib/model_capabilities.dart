// model_capabilities.dart
//
// Capacidades por modelo (issues B03X #1/#2 de Jose Manuel). NO todos los
// modelos Leapmotor soportan todas las funciones (los signal IDs varian por
// modelo). Tabla de funciones NO soportadas por modelo para OCULTAR botones.
// EDITABLE: cuando un tester confirme que una funcion no va en su modelo, se
// anade el id a su lista y se usa modeloSoporta() al pintar el boton.
library;

const String kFeatSteeringHeat = 'steering_heat';
const String kFeatMirrorHeat = 'mirror_heat';
const String kFeatSeatHeat = 'seat_heat';
const String kFeatSeatVent = 'seat_vent';
const String kFeatSunshade = 'sunshade';
const String kFeatWindows = 'windows';
const String kFeatSentry = 'sentry';
const String kFeatTrunkClose = 'trunk_close';
const String kFeatTirePressure = 'tire_pressure';

/// Set de funciones no soportadas, verificado por Jose Manuel en su B03X
/// (issue #2, lista completa 4-nov-2026).
const Set<String> kB03xUnsupported = {
  kFeatSteeringHeat,
  kFeatSeatHeat,
  kFeatSeatVent,
  kFeatSunshade,
  kFeatTrunkClose,
  kFeatTirePressure,
};

/// Modelo (mayusculas, como vehicle.carType) -> funciones no soportadas.
const Map<String, Set<String>> kUnsupportedByModel = {
  // B03X: la clave directa, por si la API lo reportara como 'B03X'.
  'B03X': kB03xUnsupported,
  // v261: el B03X reporta carType 'a10' en la API (visto en carlogs,
  // v3.60.208), NO 'B03X' — por eso en v260 el usuario no veia ningun
  // cambio ("sigue todo igual", issue #2). Mismo set verificado en B03X.
  // OJO: el T03 tambien reporta 'a10'; si un T03 difiere del B03X en
  // alguna funcion, habra que separar el mapeo por VIN.
  'A10': kB03xUnsupported,
  // - "No funcionan": calefaccion de volante y de asientos (la API las
  //   rechaza). Hoy la app SI pinta esos controles; se ocultan con esta tabla.
  // - "No aplican, no dispone del elemento": cerrar maletero (abrir SI va),
  //   persianas, ventilacion de asientos conductor/copiloto, sensores de
  //   presion de neumaticos.
  // - "Por probar" (se dejan visibles a posta): centinela, limite de
  //   velocidad.
};

/// true si el modelo (si se conoce) soporta la funcion.
bool modeloSoporta(String? carType, String feat) {
  if (carType == null || carType.isEmpty) return true;
  final no = kUnsupportedByModel[carType.toUpperCase()];
  return no == null || !no.contains(feat);
}
