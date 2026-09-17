// ios_drive_detector.dart - Deteccion de conduccion en iOS por ubicacion (v160).
//
// Por que no Bluetooth como en Android: iOS NO permite a ninguna app
// escuchar las conexiones Bluetooth del sistema (la interfaz de audio del
// coche es BT clasico, invisible para CoreBluetooth). La via nativa de iOS
// es la ubicacion: una sesion de stream de posicion INICIADA EN PRIMER
// PLANO puede continuar en segundo plano (background mode 'location' +
// allowBackgroundLocationUpdates), incluso con la pantalla apagada.
//
// Limites honestos (avisados en el propio ajuste):
//   - Si el usuario DESLIZA la app fuera (force-quit), el stream muere y no
//     hay deteccion hasta reabrirla. iOS no permite relanzarla sola sin el
//     servicio de "cambios significativos", que geolocator no expone.
//   - El detector mira el MOVIMIENTO DEL MOVIL, no el coche: yendo en
//     autobus o bici rapida detectara "conduccion". Inofensivo: sondear el
//     coche sin conducir solo gasta una llamada a la API cada 90 s.
//
// Bateria: LocationAccuracy.low + distanceFilter 100 m -> iOS usa
// triangulacion de celdas/WiFi la mayor parte del tiempo, no GPS continuo.
// Mientras este activo, iOS muestra la pastilla azul de ubicacion
// (transparencia del sistema, no se puede ocultar).
//
// La ruta en si se graba como siempre: de la posicion que reporta el COCHE
// por la API (refreshVehicleDataInBackground). El movil solo decide cuando
// sondear.

import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'car_log_bridge.dart';

/// Ajuste del usuario (interruptor en Ajustes, solo visible en iOS).
const String kIosDriveEnabledKey = 'lm_ios_drive_v1';

/// Umbral de velocidad: 3.5 m/s = 12,6 km/h. Andar (5 km/h) y correr
//  (10 km/h) quedan fuera; un coche en ciudad no baja de ahi mas que en
//  atasco parado (y ahi conviene seguir sondeando).
const double kUmbralConduccionMs = 3.5;

/// Decide si un evento de ubicacion parece conduccion. [speedMs] es la
/// velocidad que reporta iOS (-1 si no disponible: con precision baja y
/// posiciones por celda no la da); [metrosPorSegundoDist] es la velocidad
/// calculada por distancia/tiempo entre eventos como respaldo.
bool pareceConduccion({
  required double speedMs,
  required double metrosPorSegundoDist,
}) {
  final v = speedMs >= 0 ? speedMs : metrosPorSegundoDist;
  return v > kUmbralConduccionMs;
}

class IosDriveDetector {
  IosDriveDetector._();

  /// El sondeo real (refreshVehicleDataInBackground de main.dart) se inyecta
  /// desde main() para evitar un ciclo de imports main <-> detector.
  static Future<void> Function()? onSondeo;

  static StreamSubscription<Position>? _sub;
  static Timer? _watchdog;
  static DateTime? _ultimoMovimiento;
  static DateTime _ultimoSondeo =
      DateTime.fromMillisecondsSinceEpoch(0);
  static Position? _ultimaPos;
  static bool _conduciendo = false;

  static const _intervaloSondeo = Duration(seconds: 90);
  static const _paradaFin = Duration(minutes: 3);

  static bool get conduciendo => _conduciendo;

  static Future<bool> estaActivo() async =>
      (await SharedPreferences.getInstance()).getBool(kIosDriveEnabledKey) ??
      false;

  /// Activa el ajuste, pide permisos y arranca. Devuelve false si el
  /// permiso quedo denegado (el llamante muestra el aviso).
  static Future<bool> activar() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return false;
    }
    await (await SharedPreferences.getInstance())
        .setBool(kIosDriveEnabledKey, true);
    await _start();
    return true;
  }

  static Future<void> desactivar() async {
    await (await SharedPreferences.getInstance())
        .setBool(kIosDriveEnabledKey, false);
    await _stop();
  }

  /// Lo llama main() en iOS: arranca solo si el ajuste esta activado y el
  /// permiso ya concedido (no pide nada por sorpresa en el arranque).
  static Future<void> arrancarSiActivo() async {
    try {
      if (!await estaActivo()) return;
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        await CarLogBridge.log('IOS-DRIVE no arranca: permiso=$perm');
        return;
      }
      await _start();
    } catch (e) {
      await CarLogBridge.log('IOS-DRIVE arranque FALLO: ' + e.toString());
    }
  }

  static Future<void> _start() async {
    if (_sub != null) return;
    // OJO: AppleSettings NO tiene constructor const en geolocator_apple
    // 2.3.14 (fallo de analyze en z1 el 16/09/2026): esto debe ser final.
    final settings = AppleSettings(
      accuracy: LocationAccuracy.low,
      distanceFilter: 100, // eventos cada ~100 m: 12 s en ciudad, 3 s a 120
      activityType: ActivityType.otherNavigation,
      pauseLocationUpdatesAutomatically: false,
      showBackgroundLocationIndicator: true,
      allowBackgroundLocationUpdates: true,
    );
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      _onPosicion,
      onError: (Object e) async {
        await CarLogBridge.log('IOS-DRIVE stream error: ' + e.toString());
      },
    );
    _watchdog = Timer.periodic(const Duration(minutes: 1), (_) => _tick());
    await CarLogBridge.log('IOS-DRIVE detector arrancado');
  }

  static Future<void> _stop() async {
    await _sub?.cancel();
    _sub = null;
    _watchdog?.cancel();
    _watchdog = null;
    _conduciendo = false;
    _ultimaPos = null;
    _ultimoMovimiento = null;
    await CarLogBridge.log('IOS-DRIVE detector parado');
  }

  static Future<void> _onPosicion(Position p) async {
    final ahora = DateTime.now();
    var distMs = 0.0;
    final prev = _ultimaPos;
    if (prev != null) {
      final dt = ahora.difference(prev.timestamp).inMilliseconds / 1000.0;
      if (dt > 0) {
        final d = Geolocator.distanceBetween(
            prev.latitude, prev.longitude, p.latitude, p.longitude);
        distMs = d / dt;
      }
    }
    _ultimaPos = p;

    if (!pareceConduccion(speedMs: p.speed, metrosPorSegundoDist: distMs)) {
      return; // parado o andando: el watchdog cerrara la conduccion si toca
    }
    _ultimoMovimiento = ahora;
    if (!_conduciendo) {
      _conduciendo = true;
      await CarLogBridge.log('IOS-DRIVE inicio de conduccion (v=' +
          (p.speed >= 0 ? p.speed.toStringAsFixed(1) : '?') +
          ' m/s, dist=' +
          distMs.toStringAsFixed(1) +
          ' m/s)');
      await _sondear(ahora, forzar: true);
    } else if (ahora.difference(_ultimoSondeo) >= _intervaloSondeo) {
      await _sondear(ahora);
    }
  }

  static Future<void> _tick() async {
    if (!_conduciendo) return;
    final ult = _ultimoMovimiento;
    if (ult == null) return;
    if (DateTime.now().difference(ult) >= _paradaFin) {
      _conduciendo = false;
      await CarLogBridge.log('IOS-DRIVE fin de conduccion (parado 3 min)');
    }
  }

  static Future<void> _sondear(DateTime ahora, {bool forzar = false}) async {
    if (!forzar && ahora.difference(_ultimoSondeo) < _intervaloSondeo) return;
    _ultimoSondeo = ahora;
    final fn = onSondeo;
    if (fn == null) return;
    try {
      await fn();
    } catch (e) {
      await CarLogBridge.log('IOS-DRIVE sondeo FALLO: ' + e.toString());
    }
  }
}
