import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import 'vehicle_profile.dart';
import 'widget_chart.dart' show gBatteryKwh, gMaxRangeKm;

/// Eleccion del modelo de vehiculo. De estas dos cifras salen TODOS los kWh y
/// euros de la app, asi que elegir mal no rompe nada visible pero falsea todas
/// las cifras de energia.
class VehicleProfileScreen extends StatefulWidget {
  const VehicleProfileScreen({super.key});
  @override
  State<VehicleProfileScreen> createState() => _VehicleProfileScreenState();
}

class _VehicleProfileScreenState extends State<VehicleProfileScreen> {
  late String _id;
  final _kwhCtrl = TextEditingController();
  final _rangeCtrl = TextEditingController();
  final _tyreCtrl = TextEditingController();
  final _barCtrl = TextEditingController();
  double? _rangeSegunCoche;

  @override
  void initState() {
    super.initState();
    _id = kVehicleProfiles.any((p) => p.id == gProfileId) ? gProfileId : 'custom';
    _kwhCtrl.text = gBatteryKwh.toString().replaceAll('.', ',');
    _rangeCtrl.text = gMaxRangeKm.round().toString();
    _tyreCtrl.text = gTyreSize;
    _barCtrl.text = gTyreBar > 0 ? gTyreBar.toString().replaceAll('.', ',') : '';
    _estimarDelCoche();
  }

  @override
  void dispose() {
    _kwhCtrl.dispose();
    _rangeCtrl.dispose();
    _tyreCtrl.dispose();
    _barCtrl.dispose();
    super.dispose();
  }

  /// El coche declara su autonomia restante y su SOC. Dividiendo sale la
  /// autonomia a plena carga que el propio vehiculo se atribuye, que sirve
  /// para detectar que alguien ha elegido la variante equivocada. En el B10
  /// da 432 km frente a los 430 de catalogo.
  Future<void> _estimarDelCoche() async {
    try {
      final r = double.tryParse((await HomeWidget.getWidgetData<String>('range')) ?? '');
      final s = double.tryParse((await HomeWidget.getWidgetData<String>('soc')) ?? '');
      if (r != null && s != null && s > 15 && r > 0) {
        if (mounted) setState(() => _rangeSegunCoche = r / (s / 100.0));
      }
    } catch (_) {}
  }

  double? get _kwh => double.tryParse(_kwhCtrl.text.replaceAll(',', '.'));
  double? get _range => double.tryParse(_rangeCtrl.text.replaceAll(',', '.'));

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    final kwh = _kwh;
    final range = _range;
    final valido = kwh != null && kwh > 5 && kwh < 250 &&
        range != null && range > 50 && range < 1200;

    String? aviso;
    if (valido && _rangeSegunCoche != null) {
      final desvio = (_rangeSegunCoche! - range).abs() / range;
      if (desvio > 0.15) {
        aviso = es
            ? 'Tu coche declara unos ${_rangeSegunCoche!.round()} km a plena carga, '
                'bastante lejos de los $range km de este perfil. Puede que sea otra variante.'
            : 'Your car reports about ${_rangeSegunCoche!.round()} km at full charge, '
                'well away from this profile. It may be a different variant.';
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(es ? 'Perfil del vehiculo' : 'Vehicle profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            es
                ? 'La app calcula los kWh y los euros a partir de la capacidad de tu bateria. '
                    'Los porcentajes y los kilometros son correctos en cualquier modelo, pero '
                    'las cifras de energia solo si el perfil coincide con tu coche.'
                : 'The app derives kWh and cost figures from your battery capacity. '
                    'Percentages and kilometres are right on any model, but energy figures '
                    'only if this profile matches your car.',
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _id,
            decoration: InputDecoration(
              labelText: es ? 'Modelo' : 'Model',
              border: const OutlineInputBorder(),
            ),
            items: kVehicleProfiles
                .map((p) => DropdownMenuItem(value: p.id, child: Text(p.label)))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              final p = kVehicleProfiles.firstWhere((x) => x.id == v);
              setState(() {
                _id = v;
                if (v != 'custom') {
                  _kwhCtrl.text = p.kwh.toString().replaceAll('.', ',');
                  _rangeCtrl.text = p.rangeKm.round().toString();
                }
              });
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _kwhCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: es ? 'Capacidad de bateria (kWh)' : 'Battery capacity (kWh)',
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() => _id = 'custom'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _rangeCtrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: es ? 'Autonomia de catalogo (km)' : 'Manufacturer range (km)',
              border: const OutlineInputBorder(),
              helperText: es
                  ? 'De la ficha tecnica, ciclo WLTP'
                  : 'From the spec sheet, WLTP cycle',
            ),
            onChanged: (_) => setState(() => _id = 'custom'),
          ),
          if (_rangeSegunCoche != null) ...[
            const SizedBox(height: 12),
            Text(
              es
                  ? 'Tu coche declara ahora mismo unos ${_rangeSegunCoche!.round()} km a plena carga.'
                  : 'Your car currently reports about ${_rangeSegunCoche!.round()} km at full charge.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
          if (aviso != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(aviso, style: const TextStyle(fontSize: 13)),
            ),
          ],
          const SizedBox(height: 12),
          if (valido)
            Text(
              es
                  ? 'Objetivo de consumo resultante: ${(kwh / range * 100).toStringAsFixed(1).replaceAll('.', ',')} kWh/100 km'
                  : 'Resulting consumption target: ${(kwh / range * 100).toStringAsFixed(1)} kWh/100 km',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          const SizedBox(height: 24),
          Text(es ? 'Neumaticos' : 'Tyres',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _tyreCtrl,
            decoration: InputDecoration(
              labelText: es ? 'Medida' : 'Size',
              hintText: '215/60 R18',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _barCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: es ? 'Presion recomendada (bar)' : 'Recommended pressure (bar)',
              helperText: es
                  ? 'Esta en la pegatina del marco de la puerta del conductor'
                  : 'On the sticker in the driver door frame',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: !valido
                ? null
                : () async {
                    await saveVehicleProfile(id: _id, kwh: kwh, rangeKm: range);
                    await saveTyreInfo(
                        _tyreCtrl.text.trim(),
                        double.tryParse(_barCtrl.text.replaceAll(',', '.')) ?? 0);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(es
                            ? 'Perfil guardado. Las cifras se actualizan en el proximo refresco.'
                            : 'Profile saved. Figures update on the next refresh.')));
                    Navigator.of(context).pop();
                  },
            child: Text(es ? 'Guardar' : 'Save'),
          ),
          const SizedBox(height: 24),
          Text(
            es
                ? 'Los hibridos de autonomia extendida (C10 REEV) no estan soportados: su '
                    'bateria sube en marcha cuando arranca el generador, y eso falsea tanto el '
                    'consumo como la deteccion de cargas.'
                : 'Range-extender hybrids (C10 REEV) are not supported: their battery charges '
                    'while driving, which breaks both consumption and charge detection.',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
