import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'car_log_screen.dart';
import 'history_archive.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'backup_helper.dart';
import 'cert_store.dart';
import 'cert_import_screen.dart';
import 'price_screen.dart';
import 'vehicle_profile.dart';
import 'vehicle_profile_screen.dart';
import 'maintenance_screen.dart';

const _storage = FlutterSecureStorage();
const showMapKey = 'lm_show_map_v1';

Future<bool> loadShowMapSetting() async {
  final raw = await _storage.read(key: showMapKey);
  return raw != '0'; // por defecto, mostrar
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showMap = true;
  bool _hasCert = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await loadShowMapSetting();
    final c = await hasClientCert();
    setState(() { _showMap = v; _hasCert = c; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                SwitchListTile(
                  value: _showMap,
                  title: const Text('Mostrar ubicacion en el dashboard'),
                  subtitle: const Text('Direccion, distancia y acceso al mapa. Desactivalo para un dashboard solo de tiles de texto.'),
                  onChanged: (v) async {
                    setState(() => _showMap = v);
                    await _storage.write(key: showMapKey, value: v ? '1' : '0');
                  },
                ),
                const Divider(),
                ListTile(
                  leading: Icon(Icons.verified_user_outlined,
                      color: _hasCert ? Colors.green : Colors.orange),
                  title: Text(Localizations.localeOf(context).languageCode == 'es'
                      ? 'Certificado de cliente'
                      : 'Client certificate'),
                  subtitle: Text(_hasCert
                      ? (Localizations.localeOf(context).languageCode == 'es'
                          ? 'Instalado' : 'Installed')
                      : (Localizations.localeOf(context).languageCode == 'es'
                          ? 'No instalado: la app no puede conectar'
                          : 'Not installed: the app cannot connect')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const CertImportScreen()));
                    final c = await hasClientCert();
                    if (mounted) setState(() => _hasCert = c);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.build_outlined),
                  title: Text(Localizations.localeOf(context).languageCode == 'es'
                      ? 'Mantenimiento'
                      : 'Maintenance'),
                  subtitle: Text(Localizations.localeOf(context).languageCode == 'es'
                      ? 'Revisiones segun el manual del coche'
                      : 'Servicing intervals from the manual'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const MaintenanceScreen())),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.electric_car_outlined),
                  title: Text(Localizations.localeOf(context).languageCode == 'es'
                      ? 'Perfil del vehiculo'
                      : 'Vehicle profile'),
                  subtitle: Text(vehicleProfileSummary()),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const VehicleProfileScreen()));
                    if (mounted) setState(() {});
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.euro_symbol),
                  title: Text(Localizations.localeOf(context).languageCode == 'es'
                      ? 'Precio de la luz'
                      : 'Electricity price'),
                  subtitle: Text(Localizations.localeOf(context).languageCode == 'es'
                      ? 'Para calcular en euros lo que gastas conduciendo'
                      : 'To show your driving energy use in euros'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PriceScreen())),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.article_outlined),
                  title: Text(Localizations.localeOf(context).languageCode == 'es'
                      ? 'Log del coche (Android Auto)'
                      : 'Car log (Android Auto)'),
                  subtitle: Text(Localizations.localeOf(context).languageCode == 'es'
                      ? 'Diagnostico de la conexion con el coche'
                      : 'Diagnostics for the car connection'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CarLogScreen())),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.backup_outlined),
                  title: Text(Localizations.localeOf(context).languageCode == 'es'
                      ? 'Exportar copia de seguridad'
                      : 'Export backup'),
                  subtitle: Text(Localizations.localeOf(context).languageCode == 'es'
                      ? 'Comparte un archivo con tu historico (cargas y viajes)'
                      : 'Share a file with your history (charges and trips)'),
                  trailing: const Icon(Icons.share),
                  onTap: () async {
                    try {
                      final path = await BackupHelper.writeNow();
                      await Share.shareXFiles([XFile(path)], text: 'LMB10 backup');
                    } catch (_) {}
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.restore),
                  title: Text(Localizations.localeOf(context).languageCode == 'es'
                      ? 'Importar copia de seguridad'
                      : 'Import backup'),
                  subtitle: Text(Localizations.localeOf(context).languageCode == 'es'
                      ? 'Restaura tu historico desde un archivo exportado'
                      : 'Restore your history from an exported file'),
                  trailing: const Icon(Icons.folder_open),
                  onTap: () async {
                    final msg = await importHistoryBackup();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(msg)));
                  },
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    Localizations.localeOf(context).languageCode == 'es'
                        ? 'La app guarda una copia automatica cada dia en su carpeta de archivos. IMPORTANTE: esa copia se borra si desinstalas la app. Antes de desinstalar, exporta tu copia con el boton de arriba y guardala donde quieras (Drive, Telegram, etc.).'
                        : 'The app saves an automatic daily backup in its files folder. IMPORTANT: that copy is deleted if you uninstall the app. Before uninstalling, export your backup with the button above and save it somewhere safe (Drive, Telegram, etc.).',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
    );
  }
}
