import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Puente minimo de log a fichero, compartido por main.dart y por
/// leapmotor_engine.dart. Vivia dentro de main.dart, pero el motor no puede
/// importar main.dart sin crear un import circular, asi que se saca aqui.
///
/// Escribe en modo APPEND. El lado Kotlin (CarLog.kt) hace lo mismo sobre este
/// mismo fichero. No mezclar con reescrituras completas: hasta el 28/07 el
/// Kotlin reescribia el fichero entero sin salto de linea final y las lineas de
/// los dos lados se soldaban entre si.
class CarLogBridge {
  static Future<void> log(String msg) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/lmb10_history/carlog.txt');
      await f.parent.create(recursive: true);
      final ts = DateTime.now().toIso8601String().substring(5, 19);
      await f.writeAsString('$ts [DART-QA] $msg\n', mode: FileMode.append);
    } catch (_) {}
  }
}
