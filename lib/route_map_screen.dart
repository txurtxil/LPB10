// route_map_screen.dart
//
// Mapa de una ruta individual: linea entre los puntos GPS capturados durante
// el trayecto, con marcador de inicio y fin. Mismo TileLayer que
// FullMapScreen (main.dart), para no depender de una sintaxis de flutter_map
// distinta a la ya probada en produccion.
//
// Puntos espaciados (sondeo cada 90s o mas) NO siguen calles: es una linea
// recta entre lecturas, no una ruta real calculada. Si la ruta viene marcada
// como aproximada (hueco largo de muestreo), se avisa arriba del mapa en vez
// de dejarlo como si fuera preciso.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'trip_rebuild.dart' show RouteWaypoint;

const _cBlue = Color(0xFF0D3B66);
const _cGood = Color(0xFF2A9D8F);
const _cOver = Color(0xFFE76F51);

class RouteMapScreen extends StatelessWidget {
  final List<RouteWaypoint> waypoints;
  final bool aproximada;

  const RouteMapScreen({super.key, required this.waypoints, required this.aproximada});

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    final points = waypoints.map((w) => LatLng(w.lat, w.lon)).toList();
    final bounds = LatLngBounds.fromPoints(points);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _cBlue,
        title: Text(es ? 'Mapa de la ruta' : 'Route map'),
      ),
      body: Column(
        children: [
          if (aproximada)
            Container(
              width: double.infinity,
              color: _cOver,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Text(
                es
                    ? 'Puntos espaciados: la linea es aproximada, no sigue calles.'
                    : 'Widely spaced points: the line is approximate, it does not follow streets.',
                style: const TextStyle(color: Colors.white, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCameraFit: CameraFit.bounds(
                  bounds: bounds,
                  padding: const EdgeInsets.all(48),
                  maxZoom: 17,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.txurtxil.lpb10',
                ),
                PolylineLayer(polylines: [
                  Polyline(points: points, strokeWidth: 4, color: _cBlue),
                ]),
                MarkerLayer(markers: [
                  Marker(
                    point: points.first,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.trip_origin, color: _cGood, size: 28),
                  ),
                  Marker(
                    point: points.last,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.flag, color: _cOver, size: 30),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
