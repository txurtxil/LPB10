// trip_list_screen.dart
//
// Lista sencilla de las ultimas rutas: fecha, distancia, duracion y consumo
// medio. Sin graficos a proposito, es lo que pidio un tester en el foro:
// "algo sencillo, solo distancia tiempo y promedio".
import 'package:flutter/material.dart';
import 'trip_rebuild.dart';
import 'route_map_screen.dart';
import 'trip_export.dart';
import 'habitual_routes_screen.dart';

const _cBlue = Color(0xFF0D3B66);
const _cGood = Color(0xFF2A9D8F);
const _cOver = Color(0xFFE76F51);

String _fechaHora(int ts) {
  final d = DateTime.fromMillisecondsSinceEpoch(ts);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
}

/// Texto que explica por que una ruta no tiene mapa. Se ensena al tocarla,
/// no como tooltip: un tooltip pide mantener pulsado y nadie lo descubre.
String _motivoTexto(String? codigo, bool es) {
  switch (codigo) {
    case 'reconstruida':
      return es
          ? 'Sin mapa: el movil no sondeo durante el trayecto, asi que no hay '
              'puntos del recorrido. La distancia y el consumo si son exactos: '
              'salen del odometro y del SOC del propio coche.'
          : 'No map: the phone never polled during this trip, so there are no '
              'path points. Distance and consumption are still exact, taken '
              'from the car odometer and SOC.';
    case 'sin_gps':
      return es
          ? 'Sin mapa: tu coche no reporta posicion GPS a la nube, o la ruta se '
              'grabo antes de que la app capturara GPS.'
          : 'No map: your car does not report GPS position to the cloud, or the '
              'trip was recorded before the app captured GPS.';
    case 'un_punto':
      return es
          ? 'Sin mapa: solo se capturo un punto GPS, no hay recorrido que dibujar.'
          : 'No map: only one GPS point was captured, no path to draw.';
  }
  return es ? 'Sin mapa para esta ruta.' : 'No map for this trip.';
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
  String? _mesSel;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rutas = await TripRebuild.fromTrips();
    if (!mounted) return;
    setState(() {
      // Historial completo: el tope de 30 impedia consultar rutas antiguas
      // (peticion de Luck). Ya vienen ordenadas de mas reciente a mas antigua.
      _rutas = rutas;
      _loading = false;
    });
  }

  static String _mesDeTs(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}';
  }

  List<RouteTrip> get _visibles => _mesSel == null
      ? _rutas
      : _rutas.where((r) => _mesDeTs(r.startTs) == _mesSel).toList();

  Widget _chipsMeses(bool es) {
    final meses = <String>[];
    for (final r in _rutas) {
      final m = _mesDeTs(r.startTs);
      if (!meses.contains(m)) meses.add(m);
    }
    if (meses.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(es ? 'Todas' : 'All'),
              selected: _mesSel == null,
              onSelected: (_) => setState(() => _mesSel = null),
            ),
          ),
          for (final m in meses)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(m),
                selected: _mesSel == m,
                onSelected: (_) => setState(() => _mesSel = m),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    final vis = _visibles;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _cBlue,
        title: Text(es ? 'Rutas' : 'Trips'),
        actions: [
          IconButton(
            icon: const Icon(Icons.alt_route),
            tooltip: es ? 'Rutas habituales' : 'Habitual routes',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const HabitualRoutesScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: es ? 'Exportar rutas a PDF' : 'Export trips to PDF',
            onPressed: () async {
              // Se relee el historico COMPLETO aqui, no la lista capada a 30
              // que usa la pantalla para mostrar: el selector de rango de
              // exportarRutasPdf puede pedir "todo el historico".
              final todas = await TripRebuild.fromTrips();
              if (!context.mounted) return;
              await exportarRutasPdf(context, todas);
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
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
                  itemCount: vis.length + 1,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    if (i == 0) return _chipsMeses(es);
                    final r = vis[i - 1];
                    final consumo = r.kwh100 != null
                        ? '${r.kwh100!.toStringAsFixed(1)} kWh/100km'
                        : (es ? 'consumo no fiable' : 'unreliable consumption');
                    // En una ruta reconstruida solo se sabe que el viaje
                    // ocurrio dentro de la ventana startTs..endTs, que puede
                    // ser muchisimo mayor que el trayecto real (16 km dentro
                    // de un hueco de 107 min, caso real del 03/09/2026).
                    // Mostrar esa duracion enganaria, asi que se dice que no
                    // se sabe.
                    final dur = r.reconstruida
                        ? (es ? 'duracion desconocida' : 'unknown duration')
                        : '${r.aproximada ? "\u2248 " : ""}${_duracion(r.duracion)}';

                    // Velocidad media del recorrido (v3.60.191, peticion de
                    // betatester): km entre las horas de duracion. Solo con
                    // duracion conocida: en rutas reconstruidas seria
                    // enganosa. Con duracion aproximada la cifra va con ~.
                    final velMedia =
                        (!r.reconstruida && r.duracion.inMinutes > 0)
                            ? '  \u00b7  ${r.aproximada ? "\u2248 " : ""}'
                                '${(r.km / (r.duracion.inMinutes / 60.0)).round()} km/h'
                            : '';
                    return ListTile(
                      leading: const Icon(Icons.route_outlined, color: _cBlue),
                      title: Text(_fechaHora(r.startTs),
                          style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        '${r.km.toStringAsFixed(0)} km  \u00b7  $dur  \u00b7  $consumo$velMedia',
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
                          : () => ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(_motivoTexto(r.motivoSinMapa, es)),
                                  duration: const Duration(seconds: 6),
                                ),
                              ),
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
                          if (!r.hasGps)
                            const Padding(
                              padding: EdgeInsets.only(left: 6),
                              child: Icon(Icons.location_off_outlined,
                                  size: 18, color: Colors.grey),
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
