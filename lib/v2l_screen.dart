import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'leapmotor_engine.dart'
    show LeapmotorApiClient, SessionData, createStaticClient;

/// Panel V2L (vehicle-to-load): el coche como fuente de energia.
/// SOLO LECTURA: no envia ningun comando al coche.
///
/// Deteccion segun el cruce con LeapMotor Mate (canon, 2026-11-09):
/// senal 47 (puerto AC) = 2 significa V2L (verificado en coche 2026-06-19;
/// 0 = reposo, 1 = carga AC). Potencia neta entregada = 1177 x 1178 / 1000 kW,
/// gateada en corriente real de descarga (Mate: la potencia solo se entrega
/// cuando 1178 > 0). Energia de sesion = integral trapezoidal, mismo criterio
/// que battery_health.dart. La sesion sigue acumulando con la pantalla cerrada
/// (persistencia en secure-storage).
class V2lScreen extends StatefulWidget {
  const V2lScreen({super.key});
  @override
  State<V2lScreen> createState() => _V2lScreenState();
}

class _V2lScreenState extends State<V2lScreen> {
  static const _storage = FlutterSecureStorage();
  static const _kSession = 'lm_session_v1';

  Timer? _timer;
  LeapmotorApiClient? _api;
  bool _cargando = true;
  String? _error;

  // Ultima lectura viva.
  int? _modo;            // senal 47: 0 reposo / 1 AC / 2 V2L (null = sin datos)
  double? _potenciaKw;   // solo en V2L con 1178 > 0
  DateTime? _actualizado;

  // Sesion V2L (persistida: sobrevive al cierre de la pantalla y de la app).
  bool _sesionAbierta = false;
  DateTime? _sesionIni;
  double _sesionKwh = 0;
  double _totalKwh = 0;
  DateTime? _prevTs;
  double? _prevKw;

  @override
  void initState() {
    super.initState();
    _arrancar();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _persistir();
    super.dispose();
  }

  Future<void> _arrancar() async {
    await _restaurar();
    try {
      final raw = await _storage.read(key: _kSession);
      if (raw == null) {
        throw StateError(
            'Sin sesion guardada: inicia sesion en la app primero.');
      }
      final session =
          SessionData.fromMap(Map<String, String>.from(json.decode(raw) as Map));
      final staticClient = await createStaticClient();
      final api = LeapmotorApiClient(staticClient);
      await api.restoreSession(session);
      final vehicles = await api.getVehicleList();
      if (vehicles.isEmpty) {
        throw StateError('La cuenta no tiene vehiculos.');
      }
      _vin = vehicles.first.vin;
      _api = api;
      await _poll();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.toString();
      });
    }
  }

  String? _vin;

  Future<void> _restaurar() async {
    final kwh = double.tryParse(await _storage.read(key: 'v2l_sesion_kwh') ?? '');
    final tot = double.tryParse(await _storage.read(key: 'v2l_total_kwh') ?? '');
    final ini = int.tryParse(await _storage.read(key: 'v2l_sesion_ini') ?? '');
    final abierta = (await _storage.read(key: 'v2l_sesion_abierta')) == '1';
    if (!mounted) return;
    setState(() {
      _sesionKwh = kwh ?? 0;
      _totalKwh = tot ?? 0;
      _sesionIni = ini != null ? DateTime.fromMillisecondsSinceEpoch(ini) : null;
      _sesionAbierta = abierta && ini != null;
    });
  }

  Future<void> _persistir() async {
    await _storage.write(
        key: 'v2l_sesion_kwh', value: _sesionKwh.toStringAsFixed(4));
    await _storage.write(
        key: 'v2l_total_kwh', value: _totalKwh.toStringAsFixed(4));
    await _storage.write(
        key: 'v2l_sesion_abierta', value: _sesionAbierta ? '1' : '0');
    if (_sesionIni != null) {
      await _storage.write(
          key: 'v2l_sesion_ini',
          value: _sesionIni!.millisecondsSinceEpoch.toString());
    }
  }

  double? _num(dynamic x) {
    if (x is num) return x.toDouble();
    if (x is String) return double.tryParse(x);
    return null;
  }

  Future<void> _poll() async {
    final api = _api;
    final vin = _vin;
    if (api == null || vin == null) return;
    try {
      final s = await api.getVehicleStatus(vin);
      final ahora = DateTime.now();
      final modo = _num(s.raw['acInputSlowCharge'])?.toInt();
      final v = _num(s.raw['batteryVoltage']);
      final a = _num(s.raw['batteryCurrent']);
      final kw = (modo == 2 && v != null && a != null && a > 0)
          ? v * a / 1000.0
          : null;

      if (modo == 2) {
        if (!_sesionAbierta) {
          _sesionAbierta = true;
          _sesionIni = ahora;
          _sesionKwh = 0;
          _prevTs = null;
          _prevKw = null;
        }
        if (_prevTs != null && kw != null) {
          final dtH = ahora.difference(_prevTs!).inMilliseconds / 3600000.0;
          if (dtH > 0 && dtH < 1) {
            final incr = ((_prevKw ?? 0) + kw) / 2.0 * dtH;
            _sesionKwh += incr;
            _totalKwh += incr;
          }
        }
        _prevTs = ahora;
        _prevKw = kw ?? 0;
      } else if (_sesionAbierta && modo != null && modo != 2) {
        _sesionAbierta = false; // la sesion se queda registrada
        _prevTs = null;
        _prevKw = null;
      }

      await _persistir();
      if (!mounted) return;
      setState(() {
        _modo = modo;
        _potenciaKw = kw;
        _actualizado = ahora;
        _cargando = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = e.toString();
      });
    }
  }

  String get _estadoTxt {
    if (_modo == null) return 'Sin datos del puerto AC';
    if (_modo == 2) return 'V2L activo: el coche esta alimentando';
    if (_modo == 1) return 'Cargando AC (no es V2L)';
    return 'Puerto AC en reposo';
  }

  String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    return Scaffold(
      appBar: AppBar(
          title: Text(es ? 'V2L (coche como fuente)' : 'V2L (car as source)')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _poll,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                      child: ListTile(
                    leading: Icon(
                        _modo == 2 ? Icons.electric_meter : Icons.power,
                        color: _modo == 2 ? Colors.orange : null),
                    title: Text(_estadoTxt),
                    subtitle: Text(_actualizado != null
                        ? 'Actualizado hace ${DateTime.now().difference(_actualizado!).inSeconds} s'
                        : ''),
                  )),
                  const SizedBox(height: 8),
                  if (_modo == 2)
                    Card(
                        child: ListTile(
                      leading: const Icon(Icons.bolt),
                      title: Text(_potenciaKw != null
                          ? '${_potenciaKw!.toStringAsFixed(2)} kW'
                          : (es
                              ? 'Esperando corriente de descarga...'
                              : 'Waiting for discharge current...')),
                      subtitle: Text(es
                          ? 'Potencia neta entregada'
                          : 'Net delivered power'),
                    )),
                  Card(
                      child: ListTile(
                    leading: const Icon(Icons.energy_savings_leaf),
                    title: Text('${_sesionKwh.toStringAsFixed(2)} kWh'),
                    subtitle: Text(_sesionAbierta && _sesionIni != null
                        ? (es
                            ? 'Sesion abierta desde ${_hhmm(_sesionIni!)}'
                            : 'Session open since ${_hhmm(_sesionIni!)}')
                        : (es ? 'Ultima sesion' : 'Last session')),
                  )),
                  Card(
                      child: ListTile(
                    leading: const Icon(Icons.summarize),
                    title: Text('${_totalKwh.toStringAsFixed(1)} kWh'),
                    subtitle: Text(es
                        ? 'Total entregado en V2L (acumulado)'
                        : 'All-time V2L energy delivered'),
                  )),
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.red))),
                  const SizedBox(height: 12),
                  Text(
                    es
                        ? 'Solo lectura. El V2L se detecta con la senal 47=2 del '
                            'puerto AC; la potencia sale de tension x corriente de '
                            'la bateria y la energia se integra en esta app. La '
                            'sesion sigue acumulando aunque cierres la pantalla.'
                        : 'Read-only. V2L is detected via AC-port signal 47=2; '
                            'power comes from battery voltage x current and the '
                            'energy is integrated in this app. Sessions keep '
                            'accumulating with this screen closed.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
    );
  }
}
