// sentry_autoarm.dart - Centinela automatico por Bluetooth (v157).
//
// La API de Leapmotor no tiene programacion nativa del centinela (el cmdId
// 220 solo es ON/OFF inmediato; hay horarios para carga 190, clima 171,
// precondicionado 361 y FOTA 392, pero no para centinela). Asi que la
// programacion se hace aqui, en el cliente, con el evento BT como disparo:
//
//   - CarBtReceiver.kt, al DESCONECTAR el coche, encola kSentryAutoArmTaskName
//     con 3 minutos de gracia (por si la caida del BT fue momentanea) y
//     politica REPLACE. Al CONECTAR, cancela ese armado pendiente y encola
//     kSentryAutoDisarmTaskName.
//   - Este fichero decide y ejecuta en el isolate de fondo. El armado cae
//     justo al aparcar, con el TCU aun despierto (se duerme ~13 min despues),
//     asi que el comando 220 llega de inmediato: mas fiable que un horario
//     fijo de noche con el coche dormido.
//
// Reglas duras:
//   - armar SOLO si el ajuste esta activado, no se esta conduciendo, hay
//     PIN recordado y el coche NO esta encendido (snapshot);
//   - desarmar SOLO lo que armo el propio auto-armado (bandera en prefs):
//     un armado manual NUNCA se toca.
//
// debeArmarPuertas / debeArmarTrasSnapshot / debeDesarmar son puras y
// tienen test en test/sentry_autoarm_test.dart.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../car_log_bridge.dart';
import 'sentry_adapter.dart';
import 'sentry_engine.dart';
import 'sentry_store.dart';

/// Nombres de tarea WorkManager. OJO: estan DUPLICADOS como literales en
/// CarBtReceiver.kt (el lado nativo no puede importar Dart); si se cambian
/// aqui, hay que cambiarlos alla.
const String kSentryAutoArmTaskName = 'lmSentryAutoArmTask';
const String kSentryAutoDisarmTaskName = 'lmSentryAutoDisarmTask';

/// Ajuste del usuario (interruptor en la pantalla del centinela).
const String kSentryAutoArmEnabledKey = 'sentry_autoarm_enabled';

/// Bandera: el centinela actual lo armo el auto-armado. Es lo unico que el
/// auto-desarmado toca; un armado manual no la pone y se respeta siempre.
const String kSentryAutoArmActiveKey = 'sentry_autoarm_active';

/// Misma clave que _kPinKey de sentry_adapter.dart: el PIN recordado.
const String _kPinKey = 'lm_pin_v1';

/// Puertas baratas (sin red): ajuste activado, no conduciendo, PIN presente.
bool debeArmarPuertas(
        {required bool enabled, required bool conduciendo, required bool sinPin}) =>
    enabled && !conduciendo && !sinPin;

/// Puerta de red: no armar si el coche esta encendido (readyOn3 del
/// snapshot). Un null (senal desconocida) NO bloquea: mejor intentarlo que
/// dejar el coche sin vigilar por una senal que falta.
bool debeArmarTrasSnapshot({required bool? cocheEncendido}) => cocheEncendido != true;

/// Solo se desarma lo que armo el auto-armado.
bool debeDesarmar({required bool armadoPorAuto}) => armadoPorAuto;

/// Tarea WorkManager de armado. La encola el nativo al desconectar el BT
/// del coche (con 3 min de gracia); el nativo la cancela si el BT vuelve
/// antes de que se ejecute.
Future<void> ejecutarAutoArmado() async {
  const tag = 'SENTRY-AUTOARM';
  try {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(kSentryAutoArmEnabledKey) ?? false;
    final driving = await DriveFlagBridge.isSet();
    final pin = await const FlutterSecureStorage().read(key: _kPinKey) ?? '';
    if (!debeArmarPuertas(enabled: enabled, conduciendo: driving, sinPin: pin.isEmpty)) {
      await CarLogBridge.log(
          '$tag omitido (enabled=$enabled driving=$driving sinPin=${pin.isEmpty})');
      return;
    }
    final (client, vin) = await buildSentryClientConVin();
    final snap = await client.fetchSnapshot(vin);
    if (!debeArmarTrasSnapshot(cocheEncendido: snap.readyOn3)) {
      await CarLogBridge.log('$tag omitido: coche encendido');
      return;
    }
    final store = SentryStore();
    await SentryEngine(client: client, store: store).arm(vin);
    await prefs.setBool(kSentryAutoArmActiveKey, true);
    await CarLogBridge.log('$tag centinela armado por desconexion BT');
  } catch (e) {
    await CarLogBridge.log('SENTRY-AUTOARM FALLO: ' + e.toString());
  }
}

/// Tarea WorkManager de desarmado. La encola el nativo al conectar el BT
/// del coche. Si el centinela no lo armo el auto-armado, sale sin tocar
/// nada (armado manual o simplemente no armado).
Future<void> ejecutarAutoDesarmado() async {
  const tag = 'SENTRY-AUTOARM';
  try {
    final prefs = await SharedPreferences.getInstance();
    final activo = prefs.getBool(kSentryAutoArmActiveKey) ?? false;
    if (!debeDesarmar(armadoPorAuto: activo)) return;
    final (client, vin) = await buildSentryClientConVin();
    final store = SentryStore();
    await SentryEngine(client: client, store: store).disarm();
    await prefs.setBool(kSentryAutoArmActiveKey, false);
    await CarLogBridge.log('$tag centinela desarmado al volver (BT)');
  } catch (e) {
    await CarLogBridge.log('SENTRY-AUTOARM FALLO al desarmar: ' + e.toString());
  }
}
