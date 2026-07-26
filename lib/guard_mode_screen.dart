import 'package:flutter/material.dart';
import 'leapmotor_engine.dart';
import 'l10n/generated/app_localizations.dart';

/// Secuencia guiada para el truco de "grabacion continua con el coche cerrado"
/// descrito por la comunidad, mas experimentos sobre el comando de video nativo
/// (cmd 290) que podria controlar la grabadora de conduccion en bucle del B10.
class GuardModeScreen extends StatefulWidget {
  final LeapmotorApiClient client;
  final Vehicle vehicle;
  final String pin;
  const GuardModeScreen({super.key, required this.client, required this.vehicle, required this.pin});

  @override
  State<GuardModeScreen> createState() => _GuardModeScreenState();
}

class _GuardModeScreenState extends State<GuardModeScreen> {
  bool _busy = false;
  String? _message;
  final Set<int> _manualStepsChecked = {};

  Future<void> _run(String label, Future<void> Function() action) async {
    setState(() { _busy = true; _message = null; });
    try {
      await action();
      setState(() => _message = '$label: OK');
    } catch (e) {
      setState(() => _message = '$label: Error - $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vin = widget.vehicle.vin;
    final pin = widget.pin;
    final c = widget.client;

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.guardModeScreenTitle)),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.amber.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Text(
                AppLocalizations.of(context)!.guardModeWarning,
                style: const TextStyle(fontSize: 12, color: Colors.amber),
              ),
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_message!, style: const TextStyle(color: Colors.amber)),
              ),

            _stepHeader(0, AppLocalizations.of(context)!.videoCmdStepTitle, automatable: true),
            Text(
              AppLocalizations.of(context)!.videoCmdDescription,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ElevatedButton(onPressed: () => _run('video: start', () => c.videoCommand(vin, pin, 'start')), child: const Text('start')),
              ElevatedButton(onPressed: () => _run('video: stop', () => c.videoCommand(vin, pin, 'stop')), child: const Text('stop')),
              ElevatedButton(onPressed: () => _run('video: on', () => c.videoCommand(vin, pin, 'on')), child: const Text('on')),
              ElevatedButton(onPressed: () => _run('video: off', () => c.videoCommand(vin, pin, 'off')), child: const Text('off')),
              ElevatedButton(onPressed: () => _run('video: 1', () => c.videoCommand(vin, pin, '1')), child: const Text('1')),
              ElevatedButton(onPressed: () => _run('video: 0', () => c.videoCommand(vin, pin, '0')), child: const Text('0')),
            ]),
            const SizedBox(height: 16),

            _stepHeader(0, AppLocalizations.of(context)!.hotspotStepTitle, automatable: true),
            Text(
              AppLocalizations.of(context)!.hotspotDescription,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ElevatedButton(onPressed: () => _run('hotspot: {}', () => c.hotspotCommand(vin, pin, '{}')), child: const Text('{}')),
              ElevatedButton(onPressed: () => _run('hotspot: 1', () => c.hotspotCommand(vin, pin, '{"value":"1"}')), child: const Text('1')),
              ElevatedButton(onPressed: () => _run('hotspot: 0', () => c.hotspotCommand(vin, pin, '{"value":"0"}')), child: const Text('0')),
            ]),
            const SizedBox(height: 16),
            _stepHeader(1, AppLocalizations.of(context)!.pendriveStepTitle, automatable: false),
            Text(AppLocalizations.of(context)!.pendriveHint, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            _manualCheckStep(2, AppLocalizations.of(context)!.ambientLightsStep),
            _manualCheckStep(3, AppLocalizations.of(context)!.foldMirrorsStep),
            _manualCheckStep(4, AppLocalizations.of(context)!.headlightsOffStep),
            _manualCheckStep(5, AppLocalizations.of(context)!.screensOffStep),
            const SizedBox(height: 8),
            _stepHeader(6, AppLocalizations.of(context)!.campingModeStep, automatable: true),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ElevatedButton(onPressed: () => _run('Modo acampada ON', () => c.on3On(vin, pin)), child: Text(AppLocalizations.of(context)!.activateOn3)),
              OutlinedButton(onPressed: () => _run('Modo acampada OFF', () => c.on3Off(vin, pin)), child: Text(AppLocalizations.of(context)!.deactivateOn3)),
            ]),
            const SizedBox(height: 16),
            _stepHeader(7, AppLocalizations.of(context)!.openWindowStep, automatable: true),
            ElevatedButton.icon(
              icon: const Icon(Icons.window),
              label: Text(AppLocalizations.of(context)!.openWindowButton),
              onPressed: () => _run('Abrir ventanilla', () => c.windowsOpen(vin, pin)),
            ),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)!.exitCarHint, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            _stepHeader(8, AppLocalizations.of(context)!.lockCarStep, automatable: true),
            ElevatedButton.icon(
              icon: const Icon(Icons.lock),
              label: Text(AppLocalizations.of(context)!.lockButton),
              onPressed: () => _run('Bloquear', () => c.lockVehicle(vin, pin)),
            ),
            const SizedBox(height: 16),
            _stepHeader(9, AppLocalizations.of(context)!.closeWindowStep, automatable: true),
            ElevatedButton.icon(
              icon: const Icon(Icons.window_outlined),
              label: Text(AppLocalizations.of(context)!.closeWindowRemoteButton),
              onPressed: () => _run('Cerrar ventanilla (remoto)', () => c.windowsClose(vin, pin)),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                AppLocalizations.of(context)!.closeWindowFallbackHint,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepHeader(int n, String text, {required bool automatable}) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 4),
        child: Row(
          children: [
            CircleAvatar(radius: 12, child: Text('$n', style: const TextStyle(fontSize: 12))),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold))),
            Icon(automatable ? Icons.smartphone : Icons.touch_app, size: 16, color: automatable ? Colors.greenAccent : Colors.grey),
          ],
        ),
      );

  Widget _manualCheckStep(int n, String text) {
    final checked = _manualStepsChecked.contains(n);
    return CheckboxListTile(
      value: checked,
      onChanged: (v) => setState(() {
        if (v == true) {
          _manualStepsChecked.add(n);
        } else {
          _manualStepsChecked.remove(n);
        }
      }),
      title: Text('$n. $text'),
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
    );
  }
}
