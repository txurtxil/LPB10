// fota_screen.dart
//
// Consulta de actualizaciones OTA del coche (FOTA). SOLO LECTURA: muestra
// las instalaciones programadas en el vehiculo (getAppointment cmdId=392).
// No descarga ni instala nada; esos comandos (390/391) existen en la API
// pero quedan fuera de esta pantalla a proposito.
import 'package:flutter/material.dart';
import 'leapmotor_engine.dart';

class FotaScreen extends StatefulWidget {
  final LeapmotorApiClient client;
  final Vehicle vehicle;
  const FotaScreen({super.key, required this.client, required this.vehicle});

  @override
  State<FotaScreen> createState() => _FotaScreenState();
}

class _FotaScreenState extends State<FotaScreen> {
  bool _loading = true;
  String? _error;
  List<FotaScheduleEntry> _programadas = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final lista = await widget.client.getFotaSchedule(widget.vehicle.vin);
      if (!mounted) return;
      setState(() {
        _programadas = lista;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    return Scaffold(
      appBar: AppBar(
        title: Text(es ? 'Actualizacion del coche' : 'Car update'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          es
                              ? 'No se pudo consultar la programacion OTA.'
                              : 'Could not query the OTA schedule.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _load,
                          child: Text(es ? 'Reintentar' : 'Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_programadas.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              const Icon(Icons.check_circle_outline,
                                  size: 40, color: Color(0xFF2A9D8F)),
                              const SizedBox(height: 12),
                              Text(
                                es
                                    ? 'No hay ninguna instalacion OTA programada en el coche.'
                                    : 'There is no OTA install scheduled on the car.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      Text(
                        es
                            ? 'Instalaciones programadas (${_programadas.length})'
                            : 'Scheduled installs (${_programadas.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      for (final f in _programadas)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.system_update_alt),
                            title: Text(
                              es ? 'Paquete ${f.pid}' : 'Package ${f.pid}',
                            ),
                            subtitle: Text(
                              es
                                  ? 'Instalacion programada: ${f.startTime}'
                                  : 'Scheduled install: ${f.startTime}',
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      es
                          ? 'Esta pantalla solo consulta. Las descargas e instalaciones de firmware se siguen haciendo desde la app oficial o el coche.'
                          : 'This screen is read-only. Firmware downloads and installs are still done from the official app or the car.',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: Text(es ? 'Actualizar' : 'Refresh'),
                    ),
                  ],
                ),
    );
  }
}
