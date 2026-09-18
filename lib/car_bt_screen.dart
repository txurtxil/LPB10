import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'car_bt_bridge.dart';
import 'leapmotor_engine.dart';

/// Deja al usuario marcar que dispositivos Bluetooth emparejados son el
/// coche (normalmente dos: TCU/manos-libres y audio). Sin nada marcado,
/// CarBtReceiver.kt sigue reaccionando a cualquier Bluetooth (comportamiento
/// antiguo), asi que esta pantalla es opcional, no obligatoria.
class CarBtScreen extends StatefulWidget {
  /// Opcionales: habilitan la seccion "Llave Bluetooth del coche"
  /// (reinicio del modulo BLE-KEY, cmdId 430, confirmado en el B10 en v164).
  final LeapmotorApiClient? client;
  final Vehicle? vehicle;
  const CarBtScreen({super.key, this.client, this.vehicle});

  @override
  State<CarBtScreen> createState() => _CarBtScreenState();
}

class _CarBtScreenState extends State<CarBtScreen> {
  static const _pinKey = 'lm_pin_v1';
  static const _storage = FlutterSecureStorage();

  List<CarBtDevice> _paired = [];
  Set<String> _seleccion = {};
  bool _loading = true;
  bool _guardado = false;
  bool _restartingBleKey = false;
  String? _bleKeyMsg;

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

  Future<String?> _pedirPin(bool es) async {
    final guardado = await _storage.read(key: _pinKey) ?? '';
    if (guardado.isNotEmpty) return guardado;
    if (!mounted) return null;
    final ctrl = TextEditingController();
    final resultado = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(es ? 'PIN del vehiculo' : 'Vehicle PIN'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'PIN'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(es ? 'Cancelar' : 'Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(es ? 'Aceptar' : 'OK')),
        ],
      ),
    );
    return (resultado != null && resultado.isNotEmpty) ? resultado : null;
  }

  Future<void> _reiniciarLlaveBle() async {
    final es = Localizations.localeOf(context).languageCode == 'es';
    final client = widget.client;
    final vehicle = widget.vehicle;
    if (client == null || vehicle == null) return;
    final confirma = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(es ? 'Reiniciar llave Bluetooth' : 'Restart Bluetooth key'),
        content: Text(es
            ? 'Reinicia el modulo de llave Bluetooth DEL COCHE (no del movil). Usalo cuando la llave BT de la app oficial deje de responder. El coche puede tardar ~1 minuto en volver a aceptar conexiones Bluetooth.'
            : 'Restarts the CAR\'s Bluetooth key module (not the phone\'s). Use it when the official app\'s BT key stops responding. The car may take ~1 minute to accept Bluetooth connections again.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(es ? 'Cancelar' : 'Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(es ? 'Reiniciar' : 'Restart')),
        ],
      ),
    );
    if (confirma != true || !mounted) return;
    final pin = await _pedirPin(es);
    if (pin == null || !mounted) return;
    setState(() {
      _restartingBleKey = true;
      _bleKeyMsg = null;
    });
    try {
      await client.bleKeyRestart(vehicle.vin, pin);
      setState(() => _bleKeyMsg = es
          ? 'Reinicio enviado y confirmado por el coche. Espera ~1 minuto antes de usar la llave BT.'
          : 'Restart sent and confirmed by the car. Wait ~1 minute before using the BT key.');
    } catch (e) {
      setState(() => _bleKeyMsg = (es ? 'Error: ' : 'Error: ') + e.toString());
    } finally {
      if (mounted) setState(() => _restartingBleKey = false);
    }
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
                if (widget.client != null && widget.vehicle != null) ...[
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      es ? 'Llave Bluetooth del coche' : 'Car Bluetooth key',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Text(
                      es
                          ? 'Si la llave BT de la app oficial deja de responder, reinicia aqui el modulo del coche (requiere PIN).'
                          : 'If the official app\'s BT key stops responding, restart the car\'s module here (PIN required).',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ),
                  if (_restartingBleKey)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: LinearProgressIndicator(),
                    ),
                  if (_bleKeyMsg != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: Text(_bleKeyMsg!, style: const TextStyle(fontSize: 13)),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _restartingBleKey ? null : _reiniciarLlaveBle,
                        icon: const Icon(Icons.bluetooth_disabled, size: 18),
                        label: Text(es
                            ? 'Reiniciar llave Bluetooth del coche'
                            : 'Restart car Bluetooth key'),
                      ),
                    ),
                  ),
                ],
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
