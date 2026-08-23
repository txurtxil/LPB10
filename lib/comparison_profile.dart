// comparison_profile.dart
//
// Perfil de vehiculo de referencia para la pantalla comparativa (Ajustes ->
// Comparar con otro coche). Guarda dos cosas:
//   - Cuanto pagaste DE VERDAD por el B10 (no el precio de lista).
//   - Los datos del coche de referencia. Por defecto, Tesla Model 3
//     Propulsion (LFP 60 kWh, RWD), la version de entrada, la mas
//     comparable en segmento y precio al B10. Cifras de fichas y prensa
//     especializada, agosto 2026.
//
// El consumo del Tesla se guarda como RANGO (bajo/alto), no como un solo
// numero: la ficha WLTP y la prensa no coinciden entre si, y fingir una
// precision que no existe daria una comparativa mas bonita pero falsa.
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _cpStorage = FlutterSecureStorage();
const _kB10Price = 'lm_b10_precio_pagado_v1';
const _kRefVehicle = 'lm_ref_vehicle_v1';

/// Precio de lista del B10 67,1 kWh DesignProMax (ago. 2026), usado SOLO
/// como valor de partida hasta que el usuario configure lo que pago de
/// verdad. Nunca se presenta como si fuera el precio real sin confirmar.
const kB10PrecioListaDefecto = 30790.0;

class ReferenceVehicle {
  final String nombre;
  final double precio;
  final double kwh100Bajo;
  final double kwh100Alto;
  final double bateriaKwh;
  final double autonomiaKm;

  const ReferenceVehicle({
    required this.nombre,
    required this.precio,
    required this.kwh100Bajo,
    required this.kwh100Alto,
    required this.bateriaKwh,
    required this.autonomiaKm,
  });

  double get kwh100Medio => (kwh100Bajo + kwh100Alto) / 2.0;

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'precio': precio,
        'kwh100Bajo': kwh100Bajo,
        'kwh100Alto': kwh100Alto,
        'bateriaKwh': bateriaKwh,
        'autonomiaKm': autonomiaKm,
      };

  factory ReferenceVehicle.fromMap(Map<String, dynamic> m) => ReferenceVehicle(
        nombre: m['nombre'] as String? ?? kTeslaModel3.nombre,
        precio: (m['precio'] as num?)?.toDouble() ?? kTeslaModel3.precio,
        kwh100Bajo:
            (m['kwh100Bajo'] as num?)?.toDouble() ?? kTeslaModel3.kwh100Bajo,
        kwh100Alto:
            (m['kwh100Alto'] as num?)?.toDouble() ?? kTeslaModel3.kwh100Alto,
        bateriaKwh:
            (m['bateriaKwh'] as num?)?.toDouble() ?? kTeslaModel3.bateriaKwh,
        autonomiaKm:
            (m['autonomiaKm'] as num?)?.toDouble() ?? kTeslaModel3.autonomiaKm,
      );
}

const kTeslaModel3 = ReferenceVehicle(
  nombre: 'Tesla Model 3 Propulsion',
  precio: 35000,
  kwh100Bajo: 13.0, // WLTP declarado
  kwh100Alto: 18.0, // uso normal segun prensa especializada
  bateriaKwh: 60.0,
  autonomiaKm: 520.0,
);

Future<double?> loadB10PrecioPagado() async {
  final raw = await _cpStorage.read(key: _kB10Price);
  return double.tryParse(raw ?? '');
}

Future<void> saveB10PrecioPagado(double eur) async {
  await _cpStorage.write(key: _kB10Price, value: eur.toString());
}

Future<ReferenceVehicle> loadReferenceVehicle() async {
  try {
    final raw = await _cpStorage.read(key: _kRefVehicle);
    if (raw == null || raw.isEmpty) return kTeslaModel3;
    return ReferenceVehicle.fromMap(
        Map<String, dynamic>.from(json.decode(raw) as Map));
  } catch (_) {
    return kTeslaModel3;
  }
}

Future<void> saveReferenceVehicle(ReferenceVehicle v) async {
  await _cpStorage.write(key: _kRefVehicle, value: json.encode(v.toMap()));
}
