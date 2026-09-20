// Pantalla de rutas habituales (R1).
// Estilo inline es/en como trip_list_screen.dart.

import 'package:flutter/material.dart';

import 'habitual_routes.dart';
import 'route_map_screen.dart';
import 'trip_rebuild.dart';

const _cBlue = Color(0xFF1565C0);

String _durTxt(Duration d, bool es) {
  final min = d.inMinutes;
  if (min < 60) return '$min min';
  final h = min ~/ 60;
  final m = min % 60;
  return '${h}h ${m.toString().padLeft(2, '0')}min';
}

String _fecha(int ts, bool es) {
  final t = DateTime.fromMillisecondsSinceEpoch(ts);
  final dd = t.day.toString().padLeft(2, '0');
  final mm = t.month.toString().padLeft(2, '0');
  return es ? '$dd/$mm/${t.year}' : '${t.year}-$mm-$dd';
}

class HabitualRoutesScreen extends StatefulWidget {
  const HabitualRoutesScreen({super.key});
  @override
  State<HabitualRoutesScreen> createState() => _HabitualRoutesScreenState();
}

class _HabitualRoutesScreenState extends State<HabitualRoutesScreen> {
  bool _loading = true;
  List<HabitualRoute> _rutas = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final trips = await TripRebuild.fromTrips();
    if (!mounted) return;
    setState(() {
      _rutas = detectHabitualRoutes(trips);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _cBlue,
        title: Text(es ? 'Rutas habituales' : 'Habitual routes'),
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
                          ? 'Aun no se repite ninguna ruta. Cuando hagas el mismo trayecto un par de veces con GPS, aparecera aqui con sus estadisticas.'
                          : 'No repeated routes yet. Once you drive the same trip a couple of times with GPS, it will show up here with its stats.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _rutas.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final r = _rutas[i];
                    final kwh = r.kwh100Medio;
                    final stats = StringBuffer()
                      ..write('≈${r.kmMedio.toStringAsFixed(1)} km');
                    if (kwh != null) {
                      stats.write(' · ${kwh.toStringAsFixed(1)} kWh/100');
                    }
                    if (r.duracionMedia.inMinutes > 0) {
                      stats.write(' · ${_durTxt(r.duracionMedia, es)}');
                    }
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _cBlue,
                        child: Text('${i + 1}',
                            style: const TextStyle(color: Colors.white)),
                      ),
                      title: Text(es
                          ? 'Ruta ${i + 1} · ${r.viajes} viajes'
                          : 'Route ${i + 1} · ${r.viajes} trips'),
                      subtitle: Text('$stats\n'
                          '${es ? 'Ultima vez' : 'Last time'}: ${_fecha(r.ultimoTs, es)}'),
                      isThreeLine: true,
                      trailing: r.ultimoConGps == null
                          ? null
                          : const Icon(Icons.map_outlined, color: _cBlue),
                      onTap: r.ultimoConGps == null
                          ? null
                          : () {
                              final t = r.ultimoConGps!;
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => RouteMapScreen(
                                    waypoints: t.waypoints,
                                    aproximada: t.aproximada),
                              ));
                            },
                    );
                  },
                ),
    );
  }
}
