// efficient_climate.dart — Preacondicionamiento eficiente por temp exterior.
// Menos salto termico = menos A/C = mas autonomia. Solo con coche enchufado.

import 'leapmotor_engine.dart';
import 'weather.dart';

enum ClimateMode { auto, summer, mild, winter, extremeCold }

class EfficientClimateResult {
  final bool ok;
  final String summary;
  EfficientClimateResult(this.ok, this.summary);
}

/// Mapea una temperatura exterior a un modo por franjas.
ClimateMode modeForTemp(double t) {
  if (t > 28) return ClimateMode.summer;
  if (t >= 18) return ClimateMode.mild;
  if (t >= 5) return ClimateMode.winter;
  return ClimateMode.extremeCold;
}

String climateModeLabel(ClimateMode m, {required bool es}) {
  switch (m) {
    case ClimateMode.auto:
      return es ? 'Automatico (tiempo)' : 'Automatic (weather)';
    case ClimateMode.summer:
      return es ? 'Verano (frio 23)' : 'Summer (cool 23)';
    case ClimateMode.mild:
      return es ? 'Templado (sin clima)' : 'Mild (no climate)';
    case ClimateMode.winter:
      return es ? 'Invierno (calor 20)' : 'Winter (heat 20)';
    case ClimateMode.extremeCold:
      return es ? 'Frio extremo (calor+bat)' : 'Extreme cold (heat+batt)';
  }
}

/// Aplica el clima eficiente. Si [mode] es auto, consulta el tiempo por GPS.
/// Requiere coche enchufado; si no lo esta, no hace nada (y lo explica).
Future<EfficientClimateResult> applyEfficientClimate({
  required LeapmotorApiClient client,
  required String vin,
  required String pin,
  required ClimateMode mode,
  VehicleStatus? status,
  bool requirePluggedIn = true,
  bool permanent = false,
}) async {
  // Aviso (no bloquea): sin enchufe el clima gasta bateria en vez de red.
  final notPlugged = status != null && status.isPluggedIn != true;
  final warn = (requirePluggedIn && notPlugged)
      ? ' [Aviso: sin enchufar, gasta bateria]'
      : '';

  Future<void> applyHeat(String temp, bool wheel) async {
    if (permanent) {
      await client.climateManual(vin, pin, heat: true, temperature: temp);
      if (wheel) await client.steeringWheelHeatOn(vin, pin);
    } else {
      await client.prepareCarNow(vin, pin,
          heat: true, temperature: temp, steeringWheelHeat: wheel);
    }
  }
  Future<void> applyCool(String temp) async {
    if (permanent) {
      await client.climateManual(vin, pin, heat: false, temperature: temp);
    } else {
      await client.prepareCarNow(vin, pin,
          heat: false, temperature: temp, steeringWheelHeat: false);
    }
  }

  ClimateMode effective = mode;
  double? extTemp;
  if (mode == ClimateMode.auto) {
    extTemp = await Weather.outdoorTemp();
    if (extTemp == null) {
      return EfficientClimateResult(false,
          'No se pudo leer la temperatura exterior (permiso/red). Elige un modo manual.');
    }
    effective = modeForTemp(extTemp);
  }

  final tempStr = extTemp != null
      ? ' (ext ${extTemp.toStringAsFixed(0)} C)'
      : '';

  try {
    switch (effective) {
      case ClimateMode.auto:
        break; // ya resuelto
      case ClimateMode.summer:
        await applyCool('23');
        return EfficientClimateResult(true,
            'Verano$tempStr frio 23 ${permanent ? "(permanente)" : "(preacond)"}.$warn');
      case ClimateMode.mild:
        return EfficientClimateResult(true,
            'Templado$tempStr: sin climatizar. Es la zona de maxima eficiencia.');
      case ClimateMode.winter:
        await applyHeat('20', true);
        return EfficientClimateResult(true,
            'Invierno$tempStr calor 20 + volante ${permanent ? "(permanente)" : "(preacond)"}.$warn');
      case ClimateMode.extremeCold:
        await applyHeat('20', true);
        await client.batteryPreheatOn(vin, pin);
        return EfficientClimateResult(true,
            'Frio extremo$tempStr calor 20 + volante + bateria ${permanent ? "(permanente)" : "(preacond)"}.$warn');
    }
  } catch (e) {
    return EfficientClimateResult(false, 'Error al aplicar: $e');
  }
  return EfficientClimateResult(false, 'Modo no valido');
}
