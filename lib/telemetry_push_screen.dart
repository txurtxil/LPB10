// Ajustes de telemetria saliente (MQTT / webhook), clon de la integracion
// MQTT de LeapMotor Mate: cada lectura del coche se publica en el broker o
// URL del usuario (Home Assistant, Node-RED...). Opt-in total.

import 'package:flutter/material.dart';

import 'telemetry_push.dart';

class TelemetryPushScreen extends StatefulWidget {
  const TelemetryPushScreen({super.key});
  @override
  State<TelemetryPushScreen> createState() => _TelemetryPushScreenState();
}

class _TelemetryPushScreenState extends State<TelemetryPushScreen> {
  bool _cargando = true;
  bool _mqttOn = false, _tls = false, _hookOn = false;
  final _host = TextEditingController();
  final _port = TextEditingController(text: '1883');
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _topic = TextEditingController(text: 'lmb10/coche');
  final _hookUrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    TelemetryPush.cargar().then((c) {
      if (!mounted) return;
      setState(() {
        _mqttOn = c.mqttOn;
        _tls = c.tls;
        _hookOn = c.hookOn;
        _host.text = c.host;
        _port.text = c.port.toString();
        _user.text = c.user;
        _pass.text = c.pass;
        _topic.text = c.topic;
        _hookUrl.text = c.hookUrl;
        _cargando = false;
      });
    });
  }

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _user.dispose();
    _pass.dispose();
    _topic.dispose();
    _hookUrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    await TelemetryPush.guardar(ConfigTelemetria(
      mqttOn: _mqttOn,
      host: _host.text.trim(),
      port: int.tryParse(_port.text.trim()) ?? 1883,
      user: _user.text.trim(),
      pass: _pass.text,
      topic: _topic.text.trim().isEmpty ? 'lmb10/coche' : _topic.text.trim(),
      tls: _tls,
      hookOn: _hookOn,
      hookUrl: _hookUrl.text.trim(),
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(Localizations.localeOf(context).languageCode == 'es'
          ? 'Ajustes guardados'
          : 'Settings saved'),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    return Scaffold(
      appBar: AppBar(title: Text(es ? 'Telemetria (MQTT / webhook)' : 'Telemetry (MQTT / webhook)')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  es
                      ? 'Publica cada lectura del coche (SoC, km, tension, corriente, temperaturas, posicion, cargando) en tu broker MQTT o en una URL tuya, como hace LeapMotor Mate para Home Assistant. Apagado por defecto: con ambos interruptores off no se envia nada a ningun sitio. Los envios se limitan a uno por minuto.'
                      : 'Publishes each car reading (SoC, km, voltage, current, temperatures, position, charging) to your MQTT broker or your own URL, like LeapMotor Mate does for Home Assistant. Off by default: with both switches off nothing is sent anywhere. Sends are limited to one per minute.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('MQTT'),
                  subtitle: Text(es ? 'Publicar en un broker MQTT' : 'Publish to an MQTT broker'),
                  value: _mqttOn,
                  onChanged: (v) => setState(() => _mqttOn = v),
                ),
                if (_mqttOn) ...[
                  _campo(_host, es ? 'Servidor (host)' : 'Broker host'),
                  Row(
                    children: [
                      Expanded(
                          child: _campo(_port, 'Puerto',
                              teclado: TextInputType.number)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SwitchListTile(
                          title: const Text('TLS', style: TextStyle(fontSize: 14)),
                          value: _tls,
                          onChanged: (v) => setState(() => _tls = v),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                  _campo(_user, es ? 'Usuario (opcional)' : 'User (optional)'),
                  _campo(_pass, es ? 'Contrasena (opcional)' : 'Password (optional)',
                      oculto: true),
                  _campo(_topic, 'Topic'),
                ],
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Webhook'),
                  subtitle: Text(es
                      ? 'POST del mismo JSON a una URL HTTPS'
                      : 'POST the same JSON to an HTTPS URL'),
                  value: _hookOn,
                  onChanged: (v) => setState(() => _hookOn = v),
                ),
                if (_hookOn) _campo(_hookUrl, 'URL'),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    onPressed: _guardar,
                    child: Text(es ? 'Guardar' : 'Save'),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _campo(TextEditingController c, String etiqueta,
          {bool oculto = false, TextInputType? teclado}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: c,
          obscureText: oculto,
          keyboardType: teclado,
          decoration: InputDecoration(
            labelText: etiqueta,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
      );
}
