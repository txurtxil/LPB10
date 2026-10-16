import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'car_log_bridge.dart';
import 'package:lmb10/leapmotor_engine.dart';

/// Versiones de software/firmware y OTA pendiente (hotspot/fetch, v216).
/// La respuesta cruda de la API contiene secretos (downloadURL/sign/md5/
/// sha256): el parser los descarta y aqui solo se loguea el resumen.
class SoftwareScreen extends StatefulWidget {
  final LeapmotorApiClient client;
  final Vehicle vehicle;
  const SoftwareScreen({super.key, required this.client, required this.vehicle});

  @override
  State<SoftwareScreen> createState() => _SoftwareScreenState();
}

class _SoftwareScreenState extends State<SoftwareScreen> {
  late final Future<SoftwareInfo> _future;

  @override
  void initState() {
    super.initState();
    final lang = ui.PlatformDispatcher.instance.locale.languageCode;
    CarLogBridge.log('SOFTWARE peticion vin=${widget.vehicle.vin} lang=$lang');
    _future = widget.client.getSoftwareInfo(widget.vehicle.vin, language: lang);
    _future.then((info) {
      CarLogBridge.log(
          'SOFTWARE ok: actual=${info.currentVersion} ota=${info.updateAvailable} paquetes=${info.packageCount} tamano=${info.totalBytes}');
    }).catchError((e) {
      CarLogBridge.log('SOFTWARE FALLO: $e');
    });
  }

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    return Scaffold(
      appBar: AppBar(title: Text(es ? 'Software del vehiculo' : 'Vehicle software')),
      body: FutureBuilder<SoftwareInfo>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            final e = snap.error;
            final is40 = e is LeapmotorApiException && e.statusCode == 40;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  is40
                      ? (es
                          ? 'Solo el propietario puede ver esta informacion (cuenta compartida sin permiso).'
                          : 'Only the owner can see this info (shared account without permission).')
                      : 'Error: $e',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final info = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.memory),
                  title: Text(es ? 'Version instalada' : 'Installed version'),
                  subtitle: Text(
                    info.currentVersion.isEmpty
                        ? (es ? 'Desconocida' : 'Unknown')
                        : info.currentVersion,
                  ),
                  trailing: info.currentInstalledAt == null
                      ? null
                      : Text(
                          '${info.currentInstalledAt!.day.toString().padLeft(2, '0')}/${info.currentInstalledAt!.month.toString().padLeft(2, '0')}/${info.currentInstalledAt!.year}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                ),
              ),
              if (info.updateAvailable) ...[
                const SizedBox(height: 12),
                Card(
                  color: Colors.amber.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.system_update_alt, color: Colors.deepOrange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                es ? 'Actualizacion disponible' : 'Update available',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${info.newVersion ?? ''} · ${info.packageCount} ${es ? 'paquetes' : 'packages'} · ${info.totalSizeLabel}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (info.releaseNotes != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            es ? 'Notas de version' : 'Release notes',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            info.releaseNotes!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  es ? 'Paquetes por modulo' : 'Packages by module',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                for (final p in info.packages)
                  Card(
                    child: ListTile(
                      dense: true,
                      title: Text(p.product.isEmpty ? '-' : p.product),
                      subtitle: Text(
                        [
                          if (p.softversion.isNotEmpty) p.softversion,
                          if (p.softNumber.isNotEmpty) 'N. ${p.softNumber}',
                          if (p.hardware.isNotEmpty) 'HW ${p.hardware}',
                        ].join(' · '),
                      ),
                      trailing: Text(p.sizeLabel),
                    ),
                  ),
              ] else ...[
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                    title: Text(es ? 'El vehiculo esta actualizado' : 'Vehicle is up to date'),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
