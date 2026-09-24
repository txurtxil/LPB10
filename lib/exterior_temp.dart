// Temperatura exterior via Open-Meteo (API libre, sin key), con cache de
// 30 minutos: se guarda en el historico junto a cada lectura (campo 'te')
// y alimenta la grafica de consumo segun temperatura (clon Mate).
//
// Si no hay cobertura o la API falla, se devuelve la ultima conocida y el
// punto se guarda sin ella: nunca bloquea el refresco del coche.

import 'dart:convert';

import 'package:http/http.dart' as http;

class ExteriorTemp {
  static double? _temp;
  static int _fetchMs = 0;
  static double? _lat;
  static double? _lon;

  /// Parsea la respuesta de Open-Meteo (current.temperature_2m). null si el
  /// cuerpo no trae temperatura valida.
  static double? parsearTemp(String body) {
    try {
      final m = json.decode(body);
      if (m is! Map) return null;
      final cur = m['current'];
      if (cur is! Map) return null;
      final t = cur['temperature_2m'];
      return t is num ? t.toDouble() : null;
    } catch (_) {
      return null;
    }
  }

  /// Temperatura exterior actual para la posicion dada. Refresca como mucho
  /// cada 30 min (o antes si el coche se movio > ~2 km); si la red falla
  /// devuelve la ultima conocida (null si nunca hubo).
  static Future<double?> obtener(double? lat, double? lon) async {
    if (lat == null || lon == null) return _temp;
    final now = DateTime.now().millisecondsSinceEpoch;
    final movido = _lat == null ||
        _lon == null ||
        (lat - _lat!).abs() > 0.02 ||
        (lon - _lon!).abs() > 0.02;
    if (_temp != null && !movido && now - _fetchMs < 30 * 60000) return _temp;
    try {
      final uri = Uri.parse('https://api.open-meteo.com/v1/forecast'
          '?latitude=${lat.toStringAsFixed(4)}&longitude=${lon.toStringAsFixed(4)}'
          '&current=temperature_2m');
      final r = await http.get(uri).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        final t = parsearTemp(r.body);
        if (t != null) {
          _temp = t;
          _fetchMs = now;
          _lat = lat;
          _lon = lon;
        }
      }
    } catch (_) {}
    return _temp;
  }
}
