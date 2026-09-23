import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'car_log_screen.dart';
import 'car_bt_screen.dart';
import 'history_archive.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'backup_helper.dart';
import 'cert_store.dart';
import 'cert_import_screen.dart';
import 'price_screen.dart';
import 'vehicle_profile.dart';
import 'vehicle_profile_screen.dart';
import 'comparison_screen.dart';
import 'leapmotor_engine.dart';
import 'trip_list_screen.dart';
import 'maintenance_screen.dart';
import 'abrp_screen.dart';
import 'drive_backup_screen.dart';
import 'ios_drive_detector.dart';
import 'main.dart' show modoSoloLectura, setModoSoloLectura, geoHomeActivo, geoHomeGuardar, geoHomeDesactivar, pvpcAlertActivo, setPvpcAlert;
import 'package:geolocator/geolocator.dart';

const _storage = FlutterSecureStorage();
const showMapKey = 'lm_show_map_v1';

Future<bool> loadShowMapSetting() async {
  final raw = await _storage.read(key: showMapKey);
  return raw != '0'; // por defecto, mostrar
}

class SettingsScreen extends StatefulWidget {
  /// Opcionales: habilitan las fichas con datos en vivo de la API
  /// (consumo oficial en la comparativa, consulta OTA del coche).
  final LeapmotorApiClient? client;
  final Vehicle? vehicle;
  const SettingsScreen({super.key, this.client, this.vehicle});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showMap = true;
  bool _hasCert = false;
  bool _iosDrive = false;
  bool _geoHome = false;
  bool _pvpcAlert = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await loadShowMapSetting();
    final c = await hasClientCert();
    final d = Platform.isIOS ? await IosDriveDetector.estaActivo() : false;
    final g = await geoHomeActivo();
    final pa = await pvpcAlertActivo();
    setState(() { _showMap = v; _hasCert = c; _iosDrive = d; _geoHome = g; _pvpcAlert = pa; _loading = false; });
  }

  /// Activa la geocerca guardando la posicion actual como "casa". Pide el
  /// permiso de ubicacion AQUI, en primer plano (el chequeo en segundo plano
  /// nunca puede pedirlo). Si el permiso o el GPS fallan, no se activa.
  Future<void> _cambiarGeoHome(bool v) async {
    final es = Localizations.localeOf(context).languageCode == 'es';
    if (!v) {
      await geoHomeDesactivar();
      if (mounted) setState(() => _geoHome = false);
      return;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(es
                ? 'Permiso de ubicacion denegado. Hace falta para saber cuando llegas a casa.'
                : 'Location permission denied. It is needed to know when you arrive home.')));
      }
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(timeLimit: Duration(seconds: 10)));
      await geoHomeGuardar(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() => _geoHome = true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(es
                ? 'Casa guardada aqui (radio 300 m). Para cambiarla, desactiva y activa estando en el nuevo sitio.'
                : 'Home saved here (300 m radius). To change it, toggle off and on from the new place.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(es
                ? 'No se pudo leer el GPS. Intentalo en un sitio con cobertura.'
                : 'Could not read the GPS. Try somewhere with coverage.')));
      }
    }
  }

  Future<void> _cambiarIosDrive(bool v) async {
    if (v) {
      final ok = await IosDriveDetector.activar();
      if (!ok) {
        if (mounted) {
          final es = Localizations.localeOf(context).languageCode == 'es';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(es
                  ? 'Permiso de ubicacion denegado. Activalo en Ajustes de iOS > LMB10 > Ubicacion.'
                  : 'Location permission denied. Enable it in iOS Settings > LMB10 > Location.')));
        }
        return;
      }
    } else {
      await IosDriveDetector.desactivar();
    }
    if (mounted) setState(() => _iosDrive = v);
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
                SwitchListTile(
                  value: _geoHome,
                  title: Text(Localizations.localeOf(context).languageCode == 'es'
                      ? 'Recordatorio al llegar a casa'
                      : 'Reminder when arriving home'),
                  subtitle: Text(Localizations.localeOf(context).languageCode == 'es'
                      ? 'Si llegas a casa con bateria baja (30% o menos) y el coche sin enchufar, te avisa. Usa el GPS del telefono, no el del coche. Al activarlo guarda TU posicion actual como "casa".'
                      : 'If you arrive home with low battery (30% or less) and the car unplugged, it warns you. Uses the phone GPS, not the car. Enabling it saves YOUR current position as "home".'),
                  onChanged: _cambiarGeoHome,
                ),
                const Divider(),
                SwitchListTile(
                  value: _pvpcAlert,
                  title: Text(Localizations.localeOf(context).languageCode == 'es'
                      ? 'Aviso de carga barata (PVPC)'
                      : 'Cheap charging alert (PVPC)'),
                  subtitle: Text(Localizations.localeOf(context).languageCode == 'es'
                      ? 'Cuando salen los precios de manana (~20:15), si el coche esta enchufado, no cargando y por debajo del 80%, te avisa con la franja mas barata para programar la carga.'
                      : 'When tomorrow\'s prices are published (~20:15), if the car is plugged in, not charging and below 80%, it alerts you with the cheapest window to schedule charging.'),
                  onChanged: (v) async {
                    await setPvpcAlert(v);
                    if (mounted) setState(() => _pvpcAlert = v);
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
                  leading: const Icon(Icons.route_outlined),
                  title: const Text('ABRP'),
                  subtitle: Text(Localizations.localeOf(context).languageCode == 'es'
                      ? 'Planificador de rutas con tu bateria real'
                      : 'Route planner with your real battery'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const AbrpScreen())),
                ),
                _SoloLecturaSwitch(),
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
                  leading: const Icon(Icons.bar_chart_outlined),
                  title: Text(Localizations.localeOf(context).languageCode == 'es'
                      ? 'Comparar con otro coche'
                      : 'Compare with another car'),
                  subtitle: Text(Localizations.localeOf(context).languageCode == 'es'
                      ? 'Tu consumo real frente a un Tesla Model 3 (o el que configures)'
                      : 'Your real consumption vs a Tesla Model 3 (or whichever you set)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ComparisonScreen(client: widget.client, vehicle: widget.vehicle))),
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
                  leading: const Icon(Icons.route_outlined),
                  title: Text(Localizations.localeOf(context).languageCode == 'es'
                      ? 'Ultimas rutas'
                      : 'Recent trips'),
                  subtitle: Text(Localizations.localeOf(context).languageCode == 'es'
                      ? 'Distancia, duracion y consumo de cada trayecto'
                      : 'Distance, duration and consumption for each trip'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const TripListScreen())),
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
                // iOS no permite escuchar las conexiones Bluetooth del
                // sistema (v160): alla la deteccion va por ubicacion y el
                // selector BT no sirve de nada, asi que se sustituye.
                if (Platform.isIOS)
                  SwitchListTile(
                    secondary: const Icon(Icons.navigation_outlined),
                    title: Text(Localizations.localeOf(context).languageCode == 'es'
                        ? 'Deteccion de conduccion (ubicacion)'
                        : 'Drive detection (location)'),
                    subtitle: Text(Localizations.localeOf(context).languageCode == 'es'
                        ? 'iOS no permite usar el Bluetooth: se detecta al moverte. No deslices la app fuera; la pastilla azul de ubicacion quedara visible'
                        : 'iOS cannot use Bluetooth: detection works by movement. Do not swipe the app away; the blue location pill will stay visible'),
                    value: _iosDrive,
                    onChanged: _cambiarIosDrive,
                  )
                else
                  ListTile(
                    leading: const Icon(Icons.bluetooth_outlined),
                    title: Text(Localizations.localeOf(context).languageCode == 'es'
                        ? 'Bluetooth del coche'
                        : 'Car Bluetooth'),
                    subtitle: Text(Localizations.localeOf(context).languageCode == 'es'
                        ? 'Elige que dispositivos activan la deteccion de conduccion'
                        : 'Choose which devices trigger drive detection'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => CarBtScreen(client: widget.client, vehicle: widget.vehicle))),
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
                    } catch (e) {
                      // Antes se tragaba el error en silencio: en iOS el
                      // boton "no hacia nada" y no habia forma de saber por
                      // que (v158).
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Error al exportar: ' + e.toString())));
                    }
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
                ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined),
                  title: Text(Localizations.localeOf(context).languageCode == 'es'
                      ? 'Copia en Google Drive'
                      : 'Google Drive backup'),
                  subtitle: Text(Localizations.localeOf(context).languageCode == 'es'
                      ? 'Automatiza tu copia a tu propio Drive'
                      : 'Automate your backup to your own Drive'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const DriveBackupScreen())),
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


class _SoloLecturaSwitch extends StatefulWidget {
  @override
  State<_SoloLecturaSwitch> createState() => _SoloLecturaSwitchState();
}

class _SoloLecturaSwitchState extends State<_SoloLecturaSwitch> {
  bool _valor = false;
  bool _cargado = false;

  @override
  void initState() {
    super.initState();
    modoSoloLectura().then((v) {
      if (mounted) setState(() { _valor = v; _cargado = true; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    return SwitchListTile(
      value: _valor,
      onChanged: !_cargado
          ? null
          : (v) async {
              await setModoSoloLectura(v);
              setState(() => _valor = v);
            },
      title: Text(es ? 'Modo solo lectura' : 'Read-only mode'),
      subtitle: Text(
        es
            ? 'Bloquea todo comando remoto (abrir, cerrar, clima...). Solo '
                'permite ver datos del coche. Afecta a Atajos, rutinas y '
                'al widget por igual.'
            : 'Blocks every remote command (open, close, climate...). '
                'Only lets you view car data. Affects Shortcuts, routines '
                'and the widget alike.',
        style: const TextStyle(fontSize: 12),
      ),
      secondary: Icon(_valor ? Icons.visibility_outlined : Icons.lock_open_outlined),
    );
  }
}