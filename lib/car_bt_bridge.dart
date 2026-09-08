import 'package:flutter/services.dart';

/// Puente al canal nativo 'lmb10/btcar' (ver MainActivity.kt). Permite que
/// la pantalla de Ajustes lea los dispositivos Bluetooth ya emparejados y
/// guarde cuales de ellos son el coche; CarBtReceiver.kt (lado Kotlin) usa
/// esa misma seleccion para ignorar el resto.
class CarBtDevice {
  final String mac;
  final String nombre;
  const CarBtDevice(this.mac, this.nombre);
}

class CarBtBridge {
  static const _channel = MethodChannel('lmb10/btcar');

  static Future<List<CarBtDevice>> listPaired() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('listPaired') ?? [];
      return raw
          .map((e) => Map<String, dynamic>.from(e as Map))
          .map((m) => CarBtDevice(
              (m['mac'] as String?) ?? '', (m['nombre'] as String?) ?? '?'))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<Set<String>> getCarMacs() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('getCarMacs') ?? [];
      return raw.map((e) => e as String).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<void> setCarMacs(Set<String> macs) async {
    try {
      await _channel.invokeMethod('setCarMacs', {'macs': macs.toList()});
    } catch (_) {}
  }
}
