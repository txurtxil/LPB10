// Recordatorio por geocerca (N1 de la hoja de ruta "Modo Dios").
//
// La nube de Leapmotor no ofrece geocercas utilizables, pero el TELEFONO
// sabe donde esta: si al llegar a casa el coche esta bajo de bateria y sin
// enchufar, LMB10 avisa antes de que sea de noche y se olvide.
//
// Este modulo es la decision pura (testeable, sin IO): dado dentro/fuera y
// el estado del coche, decide si toca notificar. La posicion, el storage y
// la notificacion viven en main.dart.
//
// Reglas:
//  - Avisa SOLO en el flanco fuera -> dentro: si ya estabas dentro no se
//    repite el aviso en cada ciclo de sondeo.
//  - Solo si hay SoC conocido, esta por debajo del umbral y NO esta
//    enchufado (si ya carga, no hay nada que recordar).
//  - Sin lectura de posicion (distM null) no se cambia el estado ni se
//    avisa: un fallo de GPS no puede disparar ni rearmar nada.

class GeoHomeDecision {
  /// Si el telefono se considera dentro de la geocerca tras esta lectura.
  final bool dentro;

  /// Si hay que lanzar la notificacion "enchufame" en este ciclo.
  final bool avisar;

  const GeoHomeDecision(this.dentro, this.avisar);
}

GeoHomeDecision evalGeoHome({
  required double? distM,
  required double radiusM,
  required double? soc,
  required bool enchufado,
  required double socUmbral,
  required bool estabaDentro,
}) {
  if (distM == null) {
    // Sin lectura: mantener el estado anterior, jamas avisar a ciegas.
    return GeoHomeDecision(estabaDentro, false);
  }
  final dentro = distM <= radiusM;
  final flanco = dentro && !estabaDentro;
  final bateriaBaja = soc != null && soc <= socUmbral;
  return GeoHomeDecision(dentro, flanco && bateriaBaja && !enchufado);
}
