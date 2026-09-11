// charge_history_screen.dart
//
// Historial OFICIAL de cargas del coche (/carownerservice/charge/daily/detail/page).
// Solo lectura. A diferencia de la deteccion propia de la app (que solo pilla
// cargas en vivo y suele quedarse vacia), este historial viene de los
// servidores de Leapmotor y es retroactivo: ultimos 90 dias.
import 'package:flutter/material.dart';
import 'leapmotor_engine.dart';

class ChargeHistoryScreen extends StatefulWidget {
  final LeapmotorApiClient client;
  final Vehicle vehicle;
  const ChargeHistoryScreen({super.key, required this.client, required this.vehicle});

  @override
  State<ChargeHistoryScreen> createState() => _ChargeHistoryScreenState();
}

class _ChargeHistoryScreenState extends State<ChargeHistoryScreen> {
  bool _loading = true;
  String? _error;
  List<ChargeRecord> _cargas = [];

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
      final lista = await widget.client.getChargingDailyDetail(widget.vehicle.vin);
      lista.sort((a, b) => b.startTs.compareTo(a.startTs)); // recientes primero
      if (!mounted) return;
      setState(() {
        _cargas = lista;
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

  static String _fmtFecha(int tsMs) {
    final d = DateTime.fromMillisecondsSinceEpoch(tsMs);
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  static String _fmtHora(int tsMs) {
    final d = DateTime.fromMillisecondsSinceEpoch(tsMs);
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  static String _fmtDuracion(int segs) {
    if (segs <= 0) return '--';
    final h = segs ~/ 3600;
    final m = (segs % 3600) ~/ 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    return Scaffold(
      appBar: AppBar(
        title: Text(es ? 'Historial de cargas' : 'Charging history'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
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
                              ? 'No se pudo consultar el historial oficial de cargas.'
                              : 'Could not query the official charging history.',
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
              : _cargas.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          es
                              ? 'Sin cargas registradas en los ultimos 90 dias.'
                              : 'No charging sessions in the last 90 days.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _resumen(es),
                        const SizedBox(height: 12),
                        for (final c in _cargas) _fichaCarga(es, c),
                        const SizedBox(height: 8),
                        Text(
                          es
                              ? 'Datos oficiales de Leapmotor, ultimos 90 dias.'
                              : 'Official Leapmotor data, last 90 days.',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
    );
  }

  Widget _resumen(bool es) {
    final total = _cargas.fold<double>(0, (s, c) => s + c.energyKwh);
    final rapidas = _cargas.where((c) => c.isFast).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _cifra('${_cargas.length}', es ? 'cargas' : 'sessions'),
            _cifra('${total.toStringAsFixed(1)} kWh', es ? 'total' : 'total'),
            _cifra('$rapidas', es ? 'rapidas (DC)' : 'fast (DC)'),
          ],
        ),
      ),
    );
  }

  Widget _cifra(String valor, String etiqueta) => Column(
        children: [
          Text(valor, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(etiqueta, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      );

  Widget _fichaCarga(bool es, ChargeRecord c) {
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.bolt,
          color: c.isFast ? const Color(0xFFE76F51) : const Color(0xFF2A9D8F),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_fmtFecha(c.startTs)),
            Text(
              '${c.energyKwh.toStringAsFixed(2)} kWh',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        subtitle: Text(
          '${_fmtHora(c.startTs)} - ${_fmtHora(c.endTs)}  ·  ${_fmtDuracion(c.durationSeconds)}  ·  ${c.isFast ? (es ? 'Rapida DC' : 'DC fast') : (es ? 'Normal AC' : 'AC')}',
        ),
      ),
    );
  }
}
