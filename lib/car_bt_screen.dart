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

  /// v3.60.194: el usuario rechazo "Dispositivos cercanos" tras el pedido
  /// automatico. Se muestra un estado especifico con boton para reintentar.
  bool _permisoDenegado = false;
  bool _restartingBleKey = false;
  String? _bleKeyMsg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final es = Localizations.localeOf(context).languageCode == 'es';
    // v3.60.194: el permiso "Dispositivos cercanos" se pide aqui, en
    // contexto, la primera vez que hace falta. Antes la app nunca lo pedia
    // y el usuario tenia que concederlo a mano desde los Ajustes de Android
    // (con la lista de dispositivos vacia como unica pista).
    final permiso = await CarBtBridge.ensurePermission();
    if (!mounted) return;
    if (!permiso) {
      setState(() {
        _loading = false;
        _permisoDenegado = true;
      });
      return;
    }
    _permisoDenegado = false;
    final paired = await CarBtBridge.listPaired();
    var macs = await CarBtBridge.getCarMacs();
    // Auto-deteccion (v3.60.194): si no hay nada marcado todavia, se marcan
    // automaticamente los emparejados que esten CONECTADOS en este momento
    // (dentro del coche, el TCU y el audio suelen estar conectados).
    var autoDetectados = 0;
    if (macs.isEmpty) {
      final conectados = await CarBtBridge.connectedDevices();
      final validos =
          conectados.where((m) => paired.any((d) => d.mac == m)).toSet();
      if (validos.isNotEmpty) {
        macs = validos;
        await CarBtBridge.setCarMacs(macs);
        autoDetectados = validos.length;
      }
    }
    if (!mounted) return;
    setState(() {
      _paired = paired;
      _seleccion = macs;
      _loading = false;
      _guardado = autoDetectados > 0;
    });
    if (autoDetectados > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(es
              ? 'Detectados $autoDetectados dispositivos del coche: marcados automaticamente.'
              : 'Detected $autoDetectados car devices: ticked automatically.')));
    }
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
                        ? 'Marca los dispositivos Bluetooth de tu coche (normalmente dos: manos libres/TCU y audio). Si no hay nada marcado, la app detecta el coche sola: al entrar aqui con el coche conectado, marca automaticamente sus dispositivos. Sin nada marcado ni conectado, reacciona a cualquier Bluetooth (auriculares, reloj...).'
                        : 'Tick your car\'s Bluetooth devices (usually two: hands-free/TCU and audio). With nothing ticked the app detects the car itself: enter this screen with the car connected and it ticks its devices automatically. With nothing ticked or connected, it reacts to any Bluetooth (headphones, watch...).',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
                if (_permisoDenegado)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              es
                                  ? 'Sin el permiso "Dispositivos cercanos" no se pueden listar los dispositivos Bluetooth del coche.'
                                  : 'Without the "Nearby devices" permission the car Bluetooth devices cannot be listed.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                                onPressed: _load,
                                child: Text(es
                                    ? 'Conceder permiso'
                                    : 'Grant permission')),
                            const SizedBox(height: 8),
                            Text(
                              es
                                  ? 'Si lo rechazaste con "no volver a preguntar", activalo en Ajustes > Aplicaciones > LMB10 > Permisos.'
                                  : 'If you picked "don\'t ask again", enable it in Settings > Apps > LMB10 > Permissions.',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else if (_paired.isEmpty)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          es
                              ? 'No se ha encontrado ningun dispositivo emparejado. Empareja primero el coche desde los ajustes de Bluetooth de Android.'
                              : 'No paired device found. Pair the car first from Android\'s Bluetooth settings.',
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
