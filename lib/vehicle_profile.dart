import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'widget_chart.dart' show gBatteryKwh, gMaxRangeKm;

/// Perfil de vehiculo: capacidad de bateria y autonomia de catalogo.
///
/// Hasta la v3.60.26 estas dos cifras estaban cableadas al B10 (67,1 kWh y
/// 430 km) y de ellas salian TODOS los kWh y euros de la app. En cualquier
/// otro modelo los porcentajes y kilometros eran correctos pero las cifras de
/// energia no.
///
/// Ojo con dos trampas al elegir perfil:
///   - El B05 tiene DOS baterias con el mismo nombre de modelo (56,2 y 67,1).
///   - El B05 ProMax comparte bateria con el B10 pero no autonomia (482 vs
///     430), asi que capacidad y autonomia son campos independientes.
///
/// El hibrido de autonomia extendida (C10 REEV) queda fuera a proposito: su
/// bateria sube en marcha cuando arranca el generador, y eso rompe tanto el
/// calculo de consumo como la deteccion de cargas.
class VehicleProfile {
  final String id;
  final String label;
  final double kwh;
  final double rangeKm;
  const VehicleProfile(this.id, this.label, this.kwh, this.rangeKm);
}

const kVehicleProfiles = <VehicleProfile>[
  VehicleProfile('b10', 'B10  ·  67,1 kWh  ·  430 km', 67.1, 430.0),
  VehicleProfile('b05_pro', 'B05 Pro  ·  56,2 kWh  ·  401 km', 56.2, 401.0),
  VehicleProfile('b05_promax', 'B05 ProMax  ·  67,1 kWh  ·  482 km', 67.1, 482.0),
  VehicleProfile('c10', 'C10 electrico  ·  69,9 kWh  ·  420 km', 69.9, 420.0),
  VehicleProfile('custom', 'Otro  ·  a mano', 67.1, 430.0),
];

const _pStore = FlutterSecureStorage();
const _kProfileId = 'lm_profile_id_v1';
const _kProfileKwh = 'lm_profile_kwh_v1';
const _kProfileRange = 'lm_profile_range_v1';

/// Id del perfil elegido. 'b10' mientras nadie elija otra cosa, que es lo que
/// hacia la app antes y mantiene el comportamiento para los usuarios actuales.
String gProfileId = 'b10';

/// Carga el perfil y fija las globales. DEBE llamarse antes de runApp Y
/// tambien en el isolate de segundo plano del WorkManager: si no, el refresco
/// del widget de madrugada usaria los valores por defecto y daria cifras
/// distintas a las de la app en primer plano.
Future<void> loadVehicleProfile() async {
  try {
    final id = await _pStore.read(key: _kProfileId);
    final kwh = double.tryParse(await _pStore.read(key: _kProfileKwh) ?? '');
    final range = double.tryParse(await _pStore.read(key: _kProfileRange) ?? '');
    if (id != null) gProfileId = id;
    if (kwh != null && kwh > 5 && kwh < 250) gBatteryKwh = kwh;
    if (range != null && range > 50 && range < 1200) gMaxRangeKm = range;
  } catch (_) {}
}

/// Resumen corto del perfil activo, para el subtitulo en Ajustes.
String vehicleProfileSummary() =>
    gBatteryKwh.toStringAsFixed(1).replaceAll('.', ',') +
    ' kWh  \u00b7  ' + gMaxRangeKm.round().toString() + ' km';

Future<void> saveVehicleProfile({
  required String id,
  required double kwh,
  required double rangeKm,
}) async {
  gProfileId = id;
  gBatteryKwh = kwh;
  gMaxRangeKm = rangeKm;
  await _pStore.write(key: _kProfileId, value: id);
  await _pStore.write(key: _kProfileKwh, value: kwh.toString());
  await _pStore.write(key: _kProfileRange, value: rangeKm.toString());
}
