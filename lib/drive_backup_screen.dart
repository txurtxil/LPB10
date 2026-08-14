import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'drive_backup.dart';

const _driveStore = FlutterSecureStorage();
const _kAutomatico = 'lm_drive_auto_v1';

/// Copia de seguridad a Google Drive. Incluye un boton de prueba inmediata
/// para poder confirmar que el login y la subida funcionan de verdad, sin
/// esperar al ciclo automatico de 24h.
class DriveBackupScreen extends StatefulWidget {
  const DriveBackupScreen({super.key});
  @override
  State<DriveBackupScreen> createState() => _DriveBackupScreenState();
}

class _DriveBackupScreenState extends State<DriveBackupScreen> {
  bool _cargando = true;
  bool _conectando = false;
  bool _subiendo = false;
  bool _automatico = false;
  String? _email;
  String _resultado = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    _automatico = (await _driveStore.read(key: _kAutomatico)) == '1';
    final cuenta = await DriveBackup.conectarSilencioso();
    if (mounted) {
      setState(() {
        _email = cuenta?.email;
        _cargando = false;
      });
    }
  }

  Future<void> _conectar() async {
    final es = Localizations.localeOf(context).languageCode == 'es';
    setState(() { _conectando = true; _resultado = ''; });
    final cuenta = await DriveBackup.conectar();
    if (!mounted) return;
    setState(() {
      _email = cuenta?.email;
      _conectando = false;
      _resultado = cuenta == null
          ? (es ? 'No se pudo conectar.' : 'Could not connect.')
          : '';
    });
  }

  Future<void> _desconectar() async {
    await DriveBackup.desconectar();
    await _driveStore.write(key: _kAutomatico, value: '0');
    if (mounted) setState(() { _email = null; _automatico = false; _resultado = ''; });
  }

  Future<void> _subirAhora() async {
    final es = Localizations.localeOf(context).languageCode == 'es';
    setState(() { _subiendo = true; _resultado = es ? 'Subiendo...' : 'Uploading...'; });
    final ok = await DriveBackup.subirAhora();
    if (!mounted) return;
    setState(() {
      _subiendo = false;
      _resultado = ok
          ? (es ? 'Subido correctamente. Compruebalo en tu Drive.' : 'Uploaded. Check your Drive.')
          : (es
              ? 'Fallo al subir. Revisa Ajustes > Depuracion > registro, busca "Drive".'
              : 'Upload failed. Check Settings > Debug > log, search "Drive".');
    });
  }

  Future<void> _cambiarAutomatico(bool v) async {
    setState(() => _automatico = v);
    await _driveStore.write(key: _kAutomatico, value: v ? '1' : '0');
  }

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final conectado = _email != null;
    return Scaffold(
      appBar: AppBar(title: Text(es ? 'Copia en Google Drive' : 'Google Drive backup')),
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
                  ? 'Guarda copias de tu historico y tus ajustes en una carpeta '
                      '"LMB10 backups" dentro de tu propio Google Drive. Es '
                      'visible: puedes verla, abrirla o borrarla cuando '
                      'quieras. Se guardan las ultimas 6 copias, las mas '
                      'antiguas se eliminan solas.'
                  : 'Saves copies of your history and settings to a "LMB10 '
                      'backups" folder in your own Google Drive. It is '
                      'visible: you can see, open or delete it anytime. The '
                      'last 6 copies are kept, older ones are removed '
                      'automatically.',
              style: TextStyle(fontSize: 12, height: 1.35,
                  color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
          const SizedBox(height: 20),
          if (!conectado) ...[
            FilledButton.icon(
              onPressed: _conectando ? null : _conectar,
              icon: _conectando
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.login),
              label: Text(es ? 'Conectar con Google Drive' : 'Connect Google Drive'),
            ),
          ] else ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: Text(es ? 'Conectado' : 'Connected'),
              subtitle: Text(_email!),
              trailing: TextButton(
                onPressed: _desconectar,
                child: Text(es ? 'Desconectar' : 'Disconnect'),
              ),
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _automatico,
              onChanged: _cambiarAutomatico,
              title: Text(es ? 'Backup automatico diario' : 'Automatic daily backup'),
              subtitle: Text(
                es ? 'Sube una copia al dia, colgado del refresco de fondo.'
                   : 'Uploads a copy daily, hooked to the background refresh.',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _subiendo ? null : _subirAhora,
              icon: _subiendo
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.backup_outlined),
              label: Text(es ? 'Hacer backup ahora' : 'Backup now'),
            ),
          ],
          if (_resultado.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_resultado, style: const TextStyle(fontSize: 13)),
          ],
        ],
      ),
    );
  }
}
