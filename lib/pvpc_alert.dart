// Aviso de "carga barata manana" (N2 de la hoja de ruta "Modo Dios").
//
// Los precios PVPC del dia siguiente se publican hacia las 20:15. Si a esa
// hora el coche esta enchufado, no esta cargando ya y le falta bateria,
// LMB10 avisa con la ventana contigua mas barata de la madrugada: es el
// momento de programar la carga (cmd 190) o enchufar con confianza.
//
// Este modulo es la decision pura (testeable, sin IO): dado el precio de
// manana y el estado del coche, decide si toca avisar y con que ventana.
// El precio, el storage y la notificacion viven en main.dart.
//
// Reglas:
//  - Solo si los precios de manana YA estan publicados (sin ellos no hay
//    nada que decidir: se reintenta en el siguiente ciclo de sondeo).
//  - Un solo aviso por dia: se compara la fecha avisada con la de manana.
//  - Solo si el coche esta enchufado y NO cargando en este momento (si ya
//    carga, la programacion ya no sirve para hoy).
//  - Solo si el SoC conocido esta por debajo del umbral: con el 95% no hay
//    nada que programar.

import 'pvpc.dart' show cheapestWindowHours;

class PvpcAlerta {
  /// Fecha a la que se refiere el aviso, clave 'YYYY-MM-DD'.
  final String fecha;

  /// Ventana contigua mas barata, hora de inicio (0-23) y fin exclusivo.
  final int horaIni;
  final int horaFin;

  /// Precio medio de la ventana en EUR/kWh, con el descuento ya aplicado.
  final double precioMedio;

  const PvpcAlerta(this.fecha, this.horaIni, this.horaFin, this.precioMedio);
}

/// Decide si toca avisar de la carga barata de manana. Devuelve null cuando
/// no procede (sin precios, ya avisado, no enchufado, cargando o bateria
/// alta/desconocida).
PvpcAlerta? evalPvpcAlert({
  required String fechaManana,
  required List<double>? horasManana,
  required double? soc,
  required bool enchufado,
  required bool cargando,
  required String? yaAvisada,
  required double dtoPct,
  double socUmbral = 80.0,
  int duracionHoras = 3,
}) {
  if (horasManana == null || horasManana.length != 24) return null;
  if (yaAvisada == fechaManana) return null;
  if (!enchufado || cargando) return null;
  if (soc == null || soc > socUmbral) return null;

  final (ini, fin) = cheapestWindowHours(horasManana, duracionHoras);
  var suma = 0.0;
  for (var h = ini; h < fin; h++) {
    suma += horasManana[h];
  }
  final medio = suma / (fin - ini);
  final precio = dtoPct > 0 ? medio * (1 - dtoPct / 100.0) : medio;
  return PvpcAlerta(fechaManana, ini, fin, precio);
}

/// 'H:00' con cero a la izquierda, para el texto de la notificacion.
String formatoHoraPvpc(int h) =>
    '${h.toString().padLeft(2, '0')}:00';
