// fota_screen.dart
//
// Consulta de actualizaciones OTA del coche (FOTA). SOLO LECTURA: muestra
// las instalaciones programadas en el vehiculo (getAppointment cmdId=392).
// No descarga ni instala nada; esos comandos (390/391) existen en la API
// pero quedan fuera de esta pantalla a proposito.
//
// v147: registro de conexion visible en la propia ficha, con la respuesta
// cruda del servidor, para que no sea una caja negra.
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
  List<FotaScheduleEntry> _programadas = [];
  final List<String> _log = [];

  void _apunta(String msg) {
    final ts = TimeOfDay.now().format(context);
    setState(() => _log.add('$ts  $msg'));
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _programadas = [];
    });
    _apunta('Consultando instalaciones OTA programadas (getAppointment, cmdId=392)...');
    try {
      final (lista, cruda) = await widget.client.getFotaSchedule(widget.vehicle.vin);
      if (!mounted) return;
      _apunta('Respuesta del servidor: $cruda');
      _apunta(lista.isEmpty
          ? 'Resultado: ninguna instalacion programada.'
          : 'Resultado: ${lista.length} instalacion(es) programada(s).');
      setState(() {
        _programadas = lista;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      _apunta('ERROR en la consulta: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    return Scaffold(
      appBar: AppBar(
        title: Text(es ? 'Actualizacion del coche' : 'Car update'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_programadas.isEmpty)
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
                  title: Text(es ? 'Paquete ${f.pid}' : 'Package ${f.pid}'),
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
            es ? 'REGISTRO DE CONEXION' : 'CONNECTION LOG',
            style: const TextStyle(
                fontSize: 11,
                letterSpacing: 1,
                color: Colors.grey,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF10212B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              _log.isEmpty ? '...' : _log.join('\n\n'),
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  color: Color(0xFFB7E4C7),
                  height: 1.35),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            es
                ? 'Esta pantalla solo consulta. Las descargas e instalaciones de firmware se siguen haciendo desde la app oficial o el coche. La API no expone la version de firmware actual del coche: solo las instalaciones programadas.'
                : 'This screen is read-only. Firmware downloads and installs are still done from the official app or the car. The API does not expose the car\'s current firmware version: only scheduled installs.',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            label: Text(es ? 'Actualizar' : 'Refresh'),
          ),
        ],
      ),
    );
  }
}
