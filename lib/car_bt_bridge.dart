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

  /// Pide BLUETOOTH_CONNECT en runtime (v3.60.194), en contexto. Devuelve
  /// true si ya estaba concedido o el usuario acaba de aceptarlo. Antes la
  /// app nunca lo pedia y el usuario tenia que concederlo a mano desde
  /// los Ajustes de Android.
  static Future<bool> ensurePermission() async {
    try {
      final ok = await _channel.invokeMethod<bool>('ensureBtPermission');
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// MACs de los dispositivos emparejados que estan CONECTADOS ahora mismo
  /// (perfiles manos libres / A2DP: cubre TCU y audio del coche). Para
  /// auto-marcar el coche sin que el usuario tenga que saber cual es cual.
  static Future<List<String>> connectedDevices() async {
    try {
      final raw =
          await _channel.invokeMethod<List<dynamic>>('connectedDevices') ?? [];
      return raw.map((e) => e as String).toList();
    } catch (_) {
      return [];
    }
  }
}