// weather.dart — Temperatura exterior actual via GPS + Open-Meteo (sin clave).
// El coche no expone la temp exterior por API; se estima por la ubicacion.
// Cache de 15 min y fallback silencioso (null) si no hay permiso/red.

import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class Weather {
  static double? _cachedTemp;
  static DateTime? _cachedAt;

  /// Temperatura exterior en grados C, o null si no se pudo obtener.
  static Future<double?> outdoorTemp() async {
    if (_cachedTemp != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < const Duration(minutes: 15)) {
      return _cachedTemp;
    }
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
      final url = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=${pos.latitude}&longitude=${pos.longitude}&current=temperature_2m');
      final r = await http.get(url).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      final j = json.decode(r.body) as Map<String, dynamic>;
      final cur = j['current'];
      final t = (cur is Map ? cur['temperature_2m'] : null) as num?;
      if (t != null) {
        _cachedTemp = t.toDouble();
        _cachedAt = DateTime.now();
      }
      return _cachedTemp;
    } catch (_) {
      return null;
    }
  }
}
