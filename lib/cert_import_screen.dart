import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'cert_store.dart';

class CertImportScreen extends StatefulWidget {
  const CertImportScreen({super.key});
  @override
  State<CertImportScreen> createState() => _CertImportScreenState();
}

class _CertImportScreenState extends State<CertImportScreen> {
  Uint8List? _cert;
  Uint8List? _key;
  String? _certName;
  String? _keyName;
  String? _error;
  bool _installed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    hasClientCert().then((v) {
      if (mounted) setState(() => _installed = v);
    });
  }

  Future<void> _pick(bool isCert) async {
    try {
      final f = await openFile();
      if (f == null) return;
      final bytes = await f.readAsBytes();
      if (!mounted) return;
      setState(() {
        if (isCert) {
          _cert = bytes;
          _certName = f.name;
        } else {
          _key = bytes;
          _keyName = f.name;
        }
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _save(bool es) async {
    if (_cert == null || _key == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await saveClientCert(_cert!, _key!);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _installed = true;
      });
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = es
            ? 'Esos ficheros no forman un certificado valido. Comprueba que has elegido el certificado y su clave privada, y que la clave no tiene contrasena.'
            : 'Those files are not a valid certificate pair. Check you picked the certificate and its private key, and that the key has no password.';
      });
    }
  }

  Future<void> _remove(bool es) async {
    await deleteClientCert();
    if (!mounted) return;
    setState(() {
      _installed = false;
      _cert = null;
      _key = null;
      _certName = null;
      _keyName = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(es ? 'Certificado borrado' : 'Certificate removed')));
  }

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    return Scaffold(
      appBar: AppBar(
          title: Text(es ? 'Certificado de cliente' : 'Client certificate')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _installed
                  ? Colors.green.withValues(alpha: 0.15)
                  : Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Icon(_installed ? Icons.check_circle : Icons.warning_amber,
                  color: _installed ? Colors.green : Colors.orange),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_installed
                    ? (es ? 'Certificado instalado' : 'Certificate installed')
                    : (es
                        ? 'Sin certificado: la app no puede conectar'
                        : 'No certificate: the app cannot connect')),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          Text(es ? 'Por que hace falta' : 'Why this is needed',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            es
                ? 'LMB10 es una app independiente y no distribuye ningun material de Leapmotor. Para conectar con el servidor hace falta un certificado de cliente que debes obtener tu mismo. La app no lo incluye ni lo proporciona.'
                : 'LMB10 is an independent app and does not distribute any Leapmotor material. Connecting to the server requires a client certificate that you must obtain yourself. The app neither includes nor provides it.',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description_outlined),
            title: Text(es ? 'Certificado (.crt)' : 'Certificate (.crt)'),
            subtitle: Text(_certName ?? (es ? 'Sin elegir' : 'Not selected')),
            trailing: OutlinedButton(
              onPressed: _busy ? null : () => _pick(true),
              child: Text(es ? 'Elegir' : 'Pick'),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.vpn_key_outlined),
            title: Text(es ? 'Clave privada (.key)' : 'Private key (.key)'),
            subtitle: Text(_keyName ?? (es ? 'Sin elegir' : 'Not selected')),
            trailing: OutlinedButton(
              onPressed: _busy ? null : () => _pick(false),
              child: Text(es ? 'Elegir' : 'Pick'),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            label: Text(es ? 'Validar y guardar' : 'Validate and save'),
            onPressed: (_cert == null || _key == null || _busy)
                ? null
                : () => _save(es),
          ),
          if (_installed) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              label: Text(es ? 'Borrar certificado' : 'Remove certificate',
                  style: const TextStyle(color: Colors.redAccent)),
              onPressed: _busy ? null : () => _remove(es),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            es
                ? 'El certificado se guarda cifrado en este dispositivo y no se incluye en las copias de seguridad. Si desinstalas la app tendras que volver a importarlo.'
                : 'The certificate is stored encrypted on this device and is not included in backups. If you uninstall the app you will need to import it again.',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
