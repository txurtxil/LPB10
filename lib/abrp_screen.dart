import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'abrp.dart';

/// Configuracion de la integracion con A Better Route Planner.
class AbrpScreen extends StatefulWidget {
  const AbrpScreen({super.key});
  @override
  State<AbrpScreen> createState() => _AbrpScreenState();
}

class _AbrpScreenState extends State<AbrpScreen> {
  final _keyCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  bool _activo = false;
  bool _cargando = true;
  bool _guardado = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    _keyCtrl.text = await Abrp.apiKey();
    _tokenCtrl.text = await Abrp.token();
    _activo = await Abrp.activo();
    if (mounted) setState(() => _cargando = false);
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    await Abrp.guardar(
      apiKey: _keyCtrl.text,
      token: _tokenCtrl.text,
      activo: _activo && _keyCtrl.text.trim().isNotEmpty &&
          _tokenCtrl.text.trim().isNotEmpty,
    );
    if (mounted) setState(() => _guardado = true);
  }

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('ABRP')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Text(
              es
                  ? 'ABRP no ofrece una clave compartida para aplicaciones de '
                      'terceros: cada usuario necesita la suya, personal y '
                      'gratuita.\n\n'
                      '1. Entra en abetterrouteplanner.com y crea una cuenta si '
                      'no tienes.\n'
                      '2. En "Manage your telemetry API keys" crea una clave.\n'
                      '3. Dentro de ABRP, en tu vehiculo, entra en "Live data" '
                      'para conseguir el token.\n\n'
                      'Nada se envia hasta que actives el interruptor de abajo.'
                  : 'ABRP does not offer a shared key for third-party apps: '
                      'each user needs their own, personal and free.\n\n'
                      '1. Sign up at abetterrouteplanner.com if you have not.\n'
                      '2. Create a key under "Manage your telemetry API keys".\n'
                      '3. Inside ABRP, on your vehicle, open "Live data" to get '
                      'the token.\n\n'
                      'Nothing is sent until you turn on the switch below.',
              style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => launchUrl(
                Uri.parse(
                    'https://abetterrouteplanner.com/home/app/api-keys/telemetry'),
                mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(es ? 'Abrir pagina de claves' : 'Open keys page'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _keyCtrl,
            decoration: InputDecoration(
              labelText: es ? 'Clave API (personal)' : 'API key (personal)',
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() => _guardado = false),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tokenCtrl,
            decoration: InputDecoration(
              labelText: es ? 'Token del vehiculo' : 'Vehicle token',
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() => _guardado = false),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _activo,
            onChanged: (v) => setState(() { _activo = v; _guardado = false; }),
            title: Text(es ? 'Enviar telemetria' : 'Send telemetry'),
            subtitle: Text(
              es
                  ? 'Bateria, ubicacion y potencia, en cada refresco'
                  : 'Battery, location and power, on every refresh',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            es
                ? 'El coche deja de responder poco despues de aparcarlo, asi que '
                    'la telemetria solo tiene sentido mientras conduces o cargas: '
                    'fuera de eso no hay datos nuevos que mandar.'
                : 'The car stops responding shortly after parking, so telemetry '
                    'only makes sense while driving or charging: there is '
                    'nothing new to send otherwise.',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _guardar,
            child: Text(es ? 'Guardar' : 'Save'),
          ),
          if (_guardado) ...[
            const SizedBox(height: 8),
            Text(es ? 'Guardado.' : 'Saved.',
                style: const TextStyle(color: Colors.green)),
          ],
        ],
      ),
    );
  }
}
