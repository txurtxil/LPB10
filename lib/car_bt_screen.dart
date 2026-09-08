import 'package:flutter/material.dart';
import 'car_bt_bridge.dart';

/// Deja al usuario marcar que dispositivos Bluetooth emparejados son el
/// coche (normalmente dos: TCU/manos-libres y audio). Sin nada marcado,
/// CarBtReceiver.kt sigue reaccionando a cualquier Bluetooth (comportamiento
/// antiguo), asi que esta pantalla es opcional, no obligatoria.
class CarBtScreen extends StatefulWidget {
  const CarBtScreen({super.key});

  @override
  State<CarBtScreen> createState() => _CarBtScreenState();
}

class _CarBtScreenState extends State<CarBtScreen> {
  List<CarBtDevice> _paired = [];
  Set<String> _seleccion = {};
  bool _loading = true;
  bool _guardado = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final paired = await CarBtBridge.listPaired();
    final macs = await CarBtBridge.getCarMacs();
    if (!mounted) return;
    setState(() {
      _paired = paired;
      _seleccion = macs;
      _loading = false;
    });
  }

  Future<void> _guardar() async {
    await CarBtBridge.setCarMacs(_seleccion);
    if (!mounted) return;
    setState(() => _guardado = true);
  }

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    return Scaffold(
      appBar: AppBar(
          title: Text(es ? 'Bluetooth del coche' : 'Car Bluetooth')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    es
                        ? 'Marca los dispositivos Bluetooth de tu coche (normalmente dos: manos libres/TCU y audio). Sin ninguno marcado, la app sigue reaccionando a cualquier Bluetooth, incluidos auriculares o el reloj.'
                        : 'Tick your car\'s Bluetooth devices (usually two: hands-free/TCU and audio). With none ticked, the app keeps reacting to any Bluetooth, headphones or watch included.',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
                if (_paired.isEmpty)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          es
                              ? 'No se ha encontrado ningun dispositivo emparejado. Emparejalo primero desde los ajustes de Bluetooth de Android, y concede el permiso "Dispositivos cercanos" a esta app si no lo has hecho.'
                              : 'No paired device found. Pair it first from Android\'s Bluetooth settings, and grant this app the "Nearby devices" permission if you haven\'t already.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView(
                      children: _paired.map((d) {
                        final marcado = _seleccion.contains(d.mac);
                        return CheckboxListTile(
                          value: marcado,
                          title: Text(d.nombre),
                          subtitle: Text(d.mac),
                          onChanged: (v) {
                            setState(() {
                              _guardado = false;
                              if (v == true) {
                                _seleccion.add(d.mac);
                              } else {
                                _seleccion.remove(d.mac);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _paired.isEmpty ? null : _guardar,
                      child: Text(_guardado
                          ? (es ? 'Guardado' : 'Saved')
                          : (es ? 'Guardar' : 'Save')),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
