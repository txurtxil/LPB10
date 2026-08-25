// trip_list_screen.dart
//
// Lista sencilla de las ultimas rutas: fecha, distancia, duracion y consumo
// medio. Sin graficos a proposito, es lo que pidio un tester en el foro:
// "algo sencillo, solo distancia tiempo y promedio".
import 'package:flutter/material.dart';
import 'trip_rebuild.dart';
import 'route_map_screen.dart';

const _cBlue = Color(0xFF0D3B66);
const _cGood = Color(0xFF2A9D8F);
const _cOver = Color(0xFFE76F51);

String _fechaHora(int ts) {
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
}

String _duracion(Duration d) {
  final min = d.inMinutes;
  if (min < 60) return '$min min';
  final h = min ~/ 60;
  final m = min % 60;
  return '${h}h ${m.toString().padLeft(2, '0')}min';
}

class TripListScreen extends StatefulWidget {
  const TripListScreen({super.key});
  @override
  State<TripListScreen> createState() => _TripListScreenState();
}

class _TripListScreenState extends State<TripListScreen> {
  bool _loading = true;
  List<RouteTrip> _rutas = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rutas = await TripRebuild.fromTrips();
    if (!mounted) return;
    setState(() {
      // Ultimas 30, ya vienen ordenadas de mas reciente a mas antigua.
      _rutas = rutas.length > 30 ? rutas.sublist(0, 30) : rutas;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _cBlue,
        title: Text(es ? 'Ultimas rutas' : 'Recent trips'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rutas.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      es
                          ? 'Todavia no hay rutas registradas. Conduce un poco y vuelve aqui.'
                          : 'No trips recorded yet. Drive a bit and come back.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _rutas.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final r = _rutas[i];
                    final consumo = r.kwh100 != null
                        ? '${r.kwh100!.toStringAsFixed(1)} kWh/100km'
                        : (es ? 'consumo no fiable' : 'unreliable consumption');
                    return ListTile(
                      leading: const Icon(Icons.route_outlined, color: _cBlue),
                      title: Text(_fechaHora(r.startTs),
                          style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        '${r.km.toStringAsFixed(0)} km  \u00b7  ${r.aproximada ? "\u2248 " : ""}${_duracion(r.duracion)}  \u00b7  $consumo',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12.5,
                          color: r.kwh100 != null ? _cGood : Colors.grey,
                        ),
                      ),
                      onTap: r.hasGps
                          ? () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => RouteMapScreen(
                                  waypoints: r.waypoints, aproximada: r.aproximada)))
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (r.aproximada)
                            Tooltip(
                              message: es
                                  ? 'Hueco largo de muestreo dentro de la ruta: duracion aproximada'
                                  : 'Long sampling gap within the trip: duration is approximate',
                              child: const Icon(Icons.timelapse, size: 18, color: _cOver),
                            ),
                          if (r.hasGps)
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(Icons.map_outlined, size: 18, color: _cBlue),
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
