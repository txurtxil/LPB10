// sentry_screen.dart - Pantalla del Modo Centinela (v1.1, con PIN).
// Se abre desde el Dashboard igual que Guard Mode:
//   SentryScreen(vin: widget.vehicle.vin, pin: pin)

import 'dart:async';

import 'package:flutter/material.dart';

import 'sentry_adapter.dart';
import 'sentry_engine.dart';
import 'sentry_models.dart';
import 'sentry_store.dart';

class SentryScreen extends StatefulWidget {
  const SentryScreen({super.key, required this.vin, required this.pin});
  final String vin;
  final String pin;

  @override
  State<SentryScreen> createState() => _SentryScreenState();
}

class _SentryScreenState extends State<SentryScreen> {
  final _store = SentryStore();
  SentryEngine? _engine;
  String? _adapterError;

  bool _loading = true;
  bool _busy = false;
  bool _armed = false;
  bool _online = true;
  SentryConfig _cfg = const SentryConfig();
  List<SentryEvent> _log = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final client = await buildSentryClient(pin: widget.pin);
      _engine = SentryEngine(client: client, store: _store);
    } catch (e) {
      _adapterError = e.toString();
    }
    await _reload();
    if (mounted) setState(() => _loading = false);
    _restartTimer();
  }

  Future<void> _reload() async {
    _armed = await _store.loadArmed();
    _online = await _store.loadOnline();
    _cfg = await _store.loadConfig();
    _log = await _store.loadLog();
    if (mounted) setState(() {});
  }

  void _restartTimer() {
    _timer?.cancel();
    if (_armed && _engine != null) {
      _timer = Timer.periodic(Duration(seconds: _cfg.pollAwakeSec), (_) async {
        await _engine!.pollOnce();
        await _reload();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _toggleArm() async {
    final eng = _engine;
    if (eng == null) return;
    setState(() => _busy = true);
    try {
      if (_armed) {
        await eng.disarm();
      } else {
        await eng.arm(widget.vin);
      }
      await _reload();
      _restartTimer();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveCfg(SentryConfig c) async {
    _cfg = c;
    await _store.saveConfig(c);
    setState(() {});
    _restartTimer();
  }

  Future<void> _tryRecording(bool on, _S s) async {
    final eng = _engine;
    if (eng == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.recDialogTitle),
        content: Text(s.recDialogBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: Text(s.tryIt)),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    final ok = await eng.setRecording(on);
    await _reload();
    if (mounted) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? s.recAccepted : s.recRejected)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _S.of(context);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(s.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(s.title)),
      body: RefreshIndicator(
        onRefresh: () async {
          if (_engine != null && _armed) await _engine!.pollOnce();
          await _reload();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_adapterError != null) _adapterBanner(),
            _armCard(s),
            const SizedBox(height: 12),
            _howToCard(s),
            const SizedBox(height: 12),
            _recordingCard(s),
            const SizedBox(height: 12),
            _settingsCard(s),
            const SizedBox(height: 12),
            _logCard(s),
          ],
        ),
      ),
    );
  }

  Widget _adapterBanner() => Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(_adapterError ?? '',
              style: TextStyle(color: Colors.red.shade900)),
        ),
      );

  Widget _armCard(_S s) {
    final theme = Theme.of(context);
    Color dot;
    String state;
    if (!_armed) {
      dot = theme.disabledColor;
      state = s.standby;
    } else if (_online) {
      dot = Colors.green;
      state = s.watching;
    } else {
      dot = Colors.orange;
      state = s.asleep;
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.circle, size: 12, color: dot),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(state, style: theme.textTheme.titleMedium)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: (_busy || _engine == null) ? null : _toggleArm,
                icon: Icon(_armed ? Icons.shield : Icons.shield_outlined),
                label: Text(
                  _armed ? s.disarmBtn : s.armBtn,
                  style: const TextStyle(fontSize: 18),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _armed ? Colors.red.shade700 : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _howToCard(_S s) => Card(
        child: ExpansionTile(
          leading: const Icon(Icons.help_outline),
          title: Text(s.howTitle),
          subtitle: Text(s.howSubtitle),
          childrenPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            _step('1', s.howStep1),
            _step('2', s.howStep2),
            _step('3', s.howStep3),
            const Divider(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(s.howDetects,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(s.howLimits,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontStyle: FontStyle.italic)),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );

  Widget _recordingCard(_S s) => Card(
        child: ExpansionTile(
          leading: const Icon(Icons.videocam_outlined),
          title: Text(s.recTitle),
          subtitle: Text(s.recSubtitle),
          childrenPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            _step('1', s.recStep1),
            _step('2', s.recStep2),
            _step('3', s.recStep3),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(s.recParkedNote,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontStyle: FontStyle.italic)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (_busy || _engine == null)
                        ? null
                        : () => _tryRecording(true, s),
                    icon: const Icon(Icons.fiber_manual_record,
                        color: Colors.red),
                    label: Text(s.recTryOn),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (_busy || _engine == null)
                        ? null
                        : () => _tryRecording(false, s),
                    icon: const Icon(Icons.stop),
                    label: Text(s.recTryOff),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      );

  Widget _settingsCard(_S s) => Card(
        child: ExpansionTile(
          leading: const Icon(Icons.tune),
          title: Text(s.settings),
          children: [
            SwitchListTile(
              value: _cfg.useNative,
              onChanged:
                  _armed ? null : (v) => _saveCfg(_cfg.copyWith(useNative: v)),
              title: Text(s.cfgNative),
              subtitle: Text(s.cfgNativeHint),
            ),
            SwitchListTile(
              value: _cfg.useDeterrent,
              onChanged: (v) => _saveCfg(_cfg.copyWith(useDeterrent: v)),
              title: Text(s.cfgDeterrent),
              subtitle: Text(s.cfgDeterrentHint),
            ),
            SwitchListTile(
              value: _cfg.reassertLock,
              onChanged: (v) => _saveCfg(_cfg.copyWith(reassertLock: v)),
              title: Text(s.cfgRelock),
              subtitle: Text(s.cfgRelockHint),
            ),
            ListTile(
              title: Text(s.cfgMove),
              subtitle: Slider(
                min: 25,
                max: 250,
                divisions: 9,
                value: _cfg.moveMeters.clamp(25, 250),
                label: '${_cfg.moveMeters.round()} m',
                onChanged: (v) => _saveCfg(_cfg.copyWith(moveMeters: v)),
              ),
              trailing: Text('${_cfg.moveMeters.round()} m'),
            ),
            ListTile(
              title: Text(s.cfgPoll),
              trailing: DropdownButton<int>(
                value: _cfg.pollAwakeSec,
                items: const [15, 30, 60, 120]
                    .map((sec) => DropdownMenuItem<int>(
                          value: sec,
                          child: Text('$sec s'),
                        ))
                    .toList(),
                onChanged: (sec) {
                  if (sec != null) {
                    _saveCfg(_cfg.copyWith(pollAwakeSec: sec));
                  }
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );

  Widget _logCard(_S s) {
    final es = s.es;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(s.log, style: Theme.of(context).textTheme.titleSmall),
                  if (_log.isNotEmpty)
                    TextButton(
                      onPressed: () async {
                        await _store.clearLog();
                        await _reload();
                      },
                      child: Text(s.clear),
                    ),
                ],
              ),
            ),
            if (_log.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(child: Text(s.noEvents)),
              )
            else
              ..._log.map((e) => ListTile(
                    dense: true,
                    leading: Icon(_iconFor(e.type),
                        color: e.critical
                            ? Colors.red
                            : Theme.of(context).hintColor),
                    title: Text(sentryEventText(e, es: es)),
                    subtitle: Text(_fmt(e.at)),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _step(String n, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(radius: 12, child: Text(n)),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
      );

  static IconData _iconFor(SentryEventType t) {
    switch (t) {
      case SentryEventType.armed:
        return Icons.shield;
      case SentryEventType.disarmed:
        return Icons.shield_outlined;
      case SentryEventType.nativeOn:
      case SentryEventType.nativeOff:
        return Icons.sensors;
      case SentryEventType.nativeFailed:
      case SentryEventType.recFailed:
        return Icons.error_outline;
      case SentryEventType.unlock:
        return Icons.lock_open;
      case SentryEventType.door:
        return Icons.sensor_door_outlined;
      case SentryEventType.trunk:
        return Icons.inventory_2_outlined;
      case SentryEventType.window:
        return Icons.window_outlined;
      case SentryEventType.moved:
        return Icons.directions_car;
      case SentryEventType.wake:
        return Icons.power_settings_new;
      case SentryEventType.deterrent:
        return Icons.campaign;
      case SentryEventType.offline:
        return Icons.cloud_off;
      case SentryEventType.online:
        return Icons.cloud_done;
      case SentryEventType.recOn:
      case SentryEventType.recOff:
        return Icons.videocam_outlined;
    }
  }

  static String _fmt(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)}/${two(t.month)} ${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}

// -------------------------- strings es/en --------------------------
class _S {
  final bool es;
  const _S(this.es);
  factory _S.of(BuildContext c) =>
      _S(Localizations.localeOf(c).languageCode == 'es');

  String get title => es ? 'Modo Centinela' : 'Sentry Mode';
  String get standby => es ? 'En espera' : 'Standby';
  String get watching => es ? 'Vigilando el vehiculo' : 'Watching vehicle';
  String get asleep => es
      ? 'Armado - coche dormido (despierta al manipularlo)'
      : 'Armed - vehicle asleep (wakes on tamper)';
  String get armBtn => es ? 'ACTIVAR CENTINELA' : 'ARM SENTRY';
  String get disarmBtn => es ? 'DESACTIVAR' : 'DISARM';

  String get howTitle => es ? 'Como funciona' : 'How it works';
  String get howSubtitle => es ? 'Activacion en 3 pasos' : '3-step activation';
  String get howStep1 =>
      es ? 'Aparca y bloquea el coche.' : 'Park and lock the car.';
  String get howStep2 =>
      es ? 'Pulsa ACTIVAR CENTINELA (1 toque).' : 'Tap ARM SENTRY (one tap).';
  String get howStep3 => es
      ? 'Listo. Recibiras una alerta si el coche se desbloquea, se abre, se enciende o se mueve.'
      : 'Done. You will get an alert if the car unlocks, opens, powers up or moves.';
  String get howDetects => es
      ? 'Vigila: desbloqueo no solicitado, puertas, porton, encendido (READY) y movimiento/remolcado por GPS. Ademas arma el centinela del propio coche (vibracion -> claxon y luces), que funciona aunque el coche duerma.'
      : 'Watches: uncommanded unlock, doors, trunk, power-up (READY) and GPS move/tow. Also arms the car\'s own sentry (shake -> horn and lights), which works even while the car sleeps.';
  String get howLimits => es
      ? 'Limite conocido: el firmware europeo no permite grabar video aparcado, y el coche duerme ~13 min tras bloquear; parte de los avisos llegan cuando el coche despierta al ser manipulado. Para avisos con la app cerrada, recuerda el PIN en el login.'
      : 'Known limit: EU firmware disables parked video recording, and the car sleeps ~13 min after locking; some alerts arrive when tampering wakes the car. For alerts with the app closed, remember the PIN at login.';

  String get recTitle =>
      es ? 'Grabacion en marcha (dashcam)' : 'Drive recording (dashcam)';
  String get recSubtitle => es
      ? 'Camaras del coche grabando al conducir'
      : 'On-board cameras recording while driving';
  String get recStep1 => es
      ? 'Formatea un USB en FAT32 (64 GB recomendado).'
      : 'Format a USB stick as FAT32 (64 GB recommended).';
  String get recStep2 => es
      ? 'Insertalo en el puerto USB "REC" bajo el reposabrazos.'
      : 'Insert it in the "REC" USB port under the armrest.';
  String get recStep3 => es
      ? 'Al conducir, el coche graba solo, en bloques de 3 min (camaras frontal, trasera y laterales).'
      : 'While driving, the car records automatically in 3-min blocks (front, rear and side cameras).';
  String get recParkedNote => es
      ? 'Aparcado no graba: esta desactivado en el firmware UE actual. Si una OTA lo habilita, esta pantalla lo aprovechara sin cambios.'
      : 'No parked recording: disabled in current EU firmware. If an OTA enables it, this screen will benefit without changes.';
  String get recTryOn =>
      es ? 'Grabar (cmd 290 - exp.)' : 'Record (cmd 290 - exp.)';
  String get recTryOff => es ? 'Parar (exp.)' : 'Stop (exp.)';
  String get recDialogTitle =>
      es ? 'Comando experimental' : 'Experimental command';
  String get recDialogBody => es
      ? 'cmd 290 (video/dashcam) no esta confirmado en el B10. Es seguro probarlo: si el coche no lo soporta, simplemente lo rechaza.'
      : 'cmd 290 (video/dashcam) is unconfirmed on the B10. Safe to try: if unsupported, the car just rejects it.';
  String get tryIt => es ? 'Probar' : 'Try';
  String get cancel => es ? 'Cancelar' : 'Cancel';
  String get recAccepted =>
      es ? 'Comando aceptado por el backend' : 'Command accepted by backend';
  String get recRejected => es ? 'Comando rechazado' : 'Command rejected';

  String get settings => es ? 'Ajustes' : 'Settings';
  String get cfgNative =>
      es ? 'Centinela del coche (cmd 220)' : 'On-board sentry (cmd 220)';
  String get cfgNativeHint => es
      ? 'Deteccion de vibracion del propio vehiculo al armar.'
      : 'Vehicle shake detection armed with sentry.';
  String get cfgDeterrent =>
      es ? 'Disuasion: claxon + luces' : 'Deterrent: horn + lights';
  String get cfgDeterrentHint => es
      ? 'Se dispara al detectar manipulacion real.'
      : 'Fires on a detected tamper.';
  String get cfgRelock =>
      es ? 'Rebloquear si se desbloquea' : 'Re-lock on unlock';
  String get cfgRelockHint => es
      ? 'Reenvia el cierre si detecta un desbloqueo no solicitado.'
      : 'Re-sends lock on an uncommanded unlock.';
  String get cfgMove => es ? 'Sensibilidad de movimiento' : 'Move sensitivity';
  String get cfgPoll =>
      es ? 'Sondeo con la app abierta' : 'Poll with app open';

  String get log => es ? 'Registro de eventos' : 'Event log';
  String get noEvents => es ? 'Sin eventos todavia' : 'No events yet';
  String get clear => es ? 'Borrar' : 'Clear';
}
