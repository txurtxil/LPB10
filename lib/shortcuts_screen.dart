import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'main.dart' show carQuickAction, quickStatus, VehicleStatus;

const _shortcutsStore = FlutterSecureStorage();
const _kLog = 'lm_shortcuts_log_v1';

/// Atajos dentro de la app. Reutiliza carQuickAction/quickStatus, que ya
/// reconstruyen su propia sesion: esta pantalla no necesita recibir nada del
/// Dashboard.
///
/// Seguridad: lo que abre el coche exige doble toque, igual que en el widget
/// de escritorio. Lo demas es directo. El registro de uso es visible, sin
/// contraseña ni huella para consultarlo -- informar del uso, no bloquearlo.
class ShortcutsScreen extends StatefulWidget {
  const ShortcutsScreen({super.key});
  @override
  State<ShortcutsScreen> createState() => _ShortcutsScreenState();
}

class _ShortcutsScreenState extends State<ShortcutsScreen> {
  bool _cargando = true;
  bool _ejecutando = false;
  bool? _locked;
  String? _armado;
  Timer? _timer;
  List<String> _registro = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargar() async {
    final raw = await _shortcutsStore.read(key: _kLog);
    if (raw != null) {
      try {
        _registro = List<String>.from(json.decode(raw));
      } catch (_) {}
    }
    final s = await quickStatus();
    if (mounted) {
      setState(() {
        _locked = s?.isLocked;
        _cargando = false;
      });
    }
  }

  Future<void> _anotar(String accion) async {
    final ahora = DateTime.now();
    final linea = ahora.hour.toString().padLeft(2, '0') +
        ':' +
        ahora.minute.toString().padLeft(2, '0') +
        ' - ' +
        accion;
    _registro.insert(0, linea);
    if (_registro.length > 20) _registro = _registro.sublist(0, 20);
    await _shortcutsStore.write(key: _kLog, value: json.encode(_registro));
  }

  bool get _esperandoConfirmacion => _armado != null;

  void _armar(String id) {
    setState(() => _armado = id);
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _armado = null);
    });
  }

  Future<void> _ejecutar(String cmd, String label,
      {bool confirmar = false}) async {
    if (_ejecutando) return;
    if (confirmar && _armado != cmd) {
      _armar(cmd);
      return;
    }
    _timer?.cancel();
    setState(() {
      _armado = null;
      _ejecutando = true;
    });
    final ok = await carQuickAction(cmd);
    await _anotar(label + (ok ? '' : ' (fallo)'));
    if (cmd == 'lock' ||
        cmd == 'unlock' ||
        cmd == 'openall' ||
        cmd == 'closeall') {
      final s = await quickStatus();
      if (mounted) _locked = s?.isLocked ?? _locked;
    }
    if (mounted) {
      setState(() => _ejecutando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? label + ': hecho' : label + ': fallo')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: Text(es ? 'Atajos' : 'Shortcuts')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_locked != null)
            _botonGrande(
              armado: _armado == 'todo',
              locked: _locked!,
              onTap: () => _ejecutar(
                _locked! ? 'openall' : 'closeall',
                _locked! ? 'Abrir todo' : 'Cerrar todo',
                confirmar: true,
              ),
              es: es,
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _chip(Icons.lock_outline, es ? 'Cerrar' : 'Lock', 'lock', 'Cerrar'),
              _chip(Icons.ac_unit, es ? 'Frio' : 'Cool', 'cool', 'Frio rapido'),
              _chip(Icons.whatshot, es ? 'Calor' : 'Heat', 'heat', 'Calor rapido'),
              _chip(Icons.blur_on, es ? 'Desempanar' : 'Defrost', 'defrost',
                  'Desempanar'),
              _chip(Icons.location_searching, es ? 'Localizar' : 'Find',
                  'find', 'Localizar'),
              _chip(Icons.airline_seat_recline_normal,
                  es ? 'Volante' : 'Wheel', 'wheel_heat', 'Volante'),
              _chip(Icons.ev_station, es ? 'Cargador' : 'Charger',
                  'charger_unlock', 'Desbloquear cargador'),
              _chip(Icons.air, es ? 'Apagar A/C' : 'A/C off', 'ac_off',
                  'Apagar A/C'),
              _chip(Icons.wb_shade, es ? 'Parasol abrir' : 'Sunshade open',
                  'sunshade_open', 'Parasol: abrir'),
              _chip(Icons.wb_shade_outlined,
                  es ? 'Parasol cerrar' : 'Sunshade close', 'sunshade_close',
                  'Parasol: cerrar'),
              _chip(Icons.window, es ? 'Ventanillas abrir' : 'Windows open',
                  'windows_open', 'Ventanillas: abrir',
                  confirmar: true),
              _chip(Icons.window_outlined,
                  es ? 'Ventanillas cerrar' : 'Windows close',
                  'windows_close', 'Ventanillas: cerrar'),
              _chip(Icons.security, es ? 'Centinela ON' : 'Sentry ON',
                  'sentry_on', 'Centinela: activar'),
              _chip(Icons.security_outlined,
                  es ? 'Centinela OFF' : 'Sentry OFF', 'sentry_off',
                  'Centinela: desactivar'),
            ],
          ),
          const Divider(height: 32),
          Row(
            children: [
              const Icon(Icons.science_outlined, size: 18, color: Colors.orange),
              const SizedBox(width: 6),
              Text(es ? 'Experimental' : 'Experimental',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            es
                ? 'Hoy investigamos espejos calefactados y carga remota en '
                    'otros proyectos de la comunidad. No estan aqui: no '
                    'tenemos el codigo exacto que el B10 necesita, y '
                    'prefiero no adivinarlo en un boton que manda algo '
                    'real al coche. Se anadiran cuando esten verificados.'
                : 'We looked into heated mirrors and remote charging today, '
                    'seen in other community projects. Not included yet: we '
                    'do not have the exact code the B10 needs, and would '
                    'rather not guess on a button that sends something real '
                    'to the car. Added once verified.',
            style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.35),
          ),
          const Divider(height: 32),
          Text(es ? 'Registro' : 'Log',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_registro.isEmpty)
            Text(es ? 'Todavia no se ha usado nada.' : 'Nothing used yet.',
                style: const TextStyle(fontSize: 12, color: Colors.grey))
          else
            ..._registro.map((l) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(l, style: const TextStyle(fontSize: 12)),
                )),
        ],
      ),
    );
  }

  Widget _botonGrande({
    required bool armado,
    required bool locked,
    required VoidCallback onTap,
    required bool es,
  }) {
    final abrir = locked;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: armado
              ? Colors.amber
              : (abrir ? const Color(0xFF8A5A12) : const Color(0xFF0D3B66)),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        onPressed: _ejecutando ? null : onTap,
        icon: Icon(armado
            ? Icons.help_outline
            : (abrir ? Icons.lock_open : Icons.lock)),
        label: Text(
          armado
              ? (es ? 'Pulsa otra vez para confirmar' : 'Tap again to confirm')
              : (abrir
                  ? (es ? 'Abrir todo' : 'Open all')
                  : (es ? 'Cerrar todo' : 'Close all')),
          style: const TextStyle(fontSize: 15),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, String cmd, String logLabel,
      {bool confirmar = false}) {
    final armado = _armado == cmd;
    return ActionChip(
      avatar: Icon(icon, size: 18, color: armado ? Colors.amber[900] : null),
      label: Text(armado ? '¿Confirmar?' : label),
      backgroundColor: armado ? Colors.amber[100] : null,
      onPressed: _ejecutando
          ? null
          : () => _ejecutar(cmd, logLabel, confirmar: confirmar),
    );
  }
}
