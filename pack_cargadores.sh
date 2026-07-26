#!/bin/bash
# ============================================================================
# LMB10 - pack_cargadores.sh
#   La pantalla "Ubicacion del vehiculo" muestra ademas los PUNTOS DE CARGA
#   cercanos (OpenStreetMap via Overpass API, sin clave). Al tocar un cargador
#   -> panel con info + boton "Ir" que abre la navegacion en el MOVIL.
# Ejecutar desde la raiz: bash pack_cargadores.sh
# ============================================================================
set -e
[ -f lib/main.dart ] || { echo "ERROR: raiz del proyecto"; exit 1; }
mkdir -p backups_widget
cp lib/main.dart backups_widget/main.dart.bak_cargadores

python3 << 'PYEOF'
import sys
p = 'lib/main.dart'
s = open(p, encoding='utf-8').read()

if "import 'package:url_launcher/url_launcher.dart';" not in s:
    anc = "import 'package:http/http.dart' as plain_http;"
    if s.count(anc)!=1: print(f"ERROR import http: x{s.count(anc)}"); sys.exit(1)
    s = s.replace(anc, anc + "\nimport 'package:url_launcher/url_launcher.dart';")
    print("OK  import url_launcher")

old = """class FullMapScreen extends StatelessWidget {
  final double latitude;
  final double longitude;
  const FullMapScreen({super.key, required this.latitude, required this.longitude});

  @override
  Widget build(BuildContext context) {
    final point = LatLng(latitude, longitude);
    return Scaffold(
      appBar: AppBar(title: const Text('Ubicacion del vehiculo')),
      body: FlutterMap(
        options: MapOptions(initialCenter: point, initialZoom: 16.0),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
            subdomains: const ['a', 'b', 'c', 'd'],
            userAgentPackageName: 'com.txurtxil.lpb10',
          ),
          MarkerLayer(markers: [
            Marker(point: point, width: 46, height: 46, child: const Icon(Icons.directions_car, color: Colors.deepPurple, size: 38)),
          ]),
        ],
      ),
    );
  }
}"""

new = """class _Charger {
  final double lat;
  final double lon;
  final String name;
  final String? operator;
  final String? power;
  _Charger(this.lat, this.lon, this.name, this.operator, this.power);
}

class FullMapScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  const FullMapScreen({super.key, required this.latitude, required this.longitude});

  @override
  State<FullMapScreen> createState() => _FullMapScreenState();
}

class _FullMapScreenState extends State<FullMapScreen> {
  List<_Charger> _chargers = [];
  bool _loading = false;
  bool _tried = false;

  @override
  void initState() {
    super.initState();
    _loadChargers();
  }

  Future<void> _loadChargers() async {
    setState(() => _loading = true);
    try {
      final lat = widget.latitude, lon = widget.longitude;
      final q =
          '[out:json][timeout:20];node[\"amenity\"=\"charging_station\"](around:5000,$lat,$lon);out body 60;';
      final uri = Uri.parse('https://overpass-api.de/api/interpreter');
      final resp = await plain_http.post(uri,
          headers: {'User-Agent': 'LMB10-app (uso personal)'},
          body: {'data': q}).timeout(const Duration(seconds: 25));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final els = (data['elements'] as List?) ?? [];
        final list = <_Charger>[];
        for (final e in els) {
          final m = Map<String, dynamic>.from(e as Map);
          final la = (m['lat'] as num?)?.toDouble();
          final lo = (m['lon'] as num?)?.toDouble();
          if (la == null || lo == null) continue;
          final tags = Map<String, dynamic>.from(m['tags'] ?? {});
          final name = (tags['name'] ?? tags['operator'] ?? 'Punto de carga').toString();
          final op = tags['operator']?.toString();
          final power = (tags['maxpower'] ?? tags['socket:type2:output'] ?? tags['charging_station:output'])?.toString();
          list.add(_Charger(la, lo, name, op, power));
        }
        if (mounted) setState(() => _chargers = list);
      }
    } catch (_) {
    }
    if (mounted) setState(() { _loading = false; _tried = true; });
  }

  Future<void> _navigateTo(_Charger c) async {
    final es = Localizations.localeOf(context).languageCode == 'es';
    final uris = [
      Uri.parse('google.navigation:q=${c.lat},${c.lon}'),
      Uri.parse('geo:${c.lat},${c.lon}?q=${c.lat},${c.lon}(${Uri.encodeComponent(c.name)})'),
      Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${c.lat},${c.lon}'),
    ];
    for (final u in uris) {
      if (await canLaunchUrl(u)) {
        await launchUrl(u, mode: LaunchMode.externalApplication);
        return;
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(es ? 'No se pudo abrir la navegacion' : 'Could not open navigation')));
    }
  }

  void _showCharger(_Charger c) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    final dist = Geolocator.distanceBetween(widget.latitude, widget.longitude, c.lat, c.lon);
    final distStr = dist >= 1000 ? '${(dist / 1000).toStringAsFixed(1)} km' : '${dist.round()} m';
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.ev_station, color: Color(0xFF2A9D8F), size: 28),
                const SizedBox(width: 10),
                Expanded(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              ],
            ),
            const SizedBox(height: 8),
            if (c.operator != null) Text('${es ? 'Operador' : 'Operator'}: ${c.operator}'),
            if (c.power != null) Text('${es ? 'Potencia' : 'Power'}: ${c.power}'),
            Text('${es ? 'Distancia' : 'Distance'}: $distStr'),
            const SizedBox(height: 4),
            Text(
              es ? 'Datos de OpenStreetMap. Sin disponibilidad en vivo.' : 'OpenStreetMap data. No live availability.',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () { Navigator.pop(context); _navigateTo(c); },
                icon: const Icon(Icons.directions),
                label: Text(es ? 'Ir (en el movil)' : 'Go (on phone)'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final es = Localizations.localeOf(context).languageCode == 'es';
    final point = LatLng(widget.latitude, widget.longitude);
    return Scaffold(
      appBar: AppBar(
        title: Text(es ? 'Ubicacion del vehiculo' : 'Vehicle location'),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.ev_station),
              tooltip: es ? 'Buscar cargadores' : 'Find chargers',
              onPressed: _loadChargers,
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(initialCenter: point, initialZoom: 15.0),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.txurtxil.lpb10',
              ),
              MarkerLayer(markers: [
                for (final c in _chargers)
                  Marker(
                    point: LatLng(c.lat, c.lon),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () => _showCharger(c),
                      child: const Icon(Icons.ev_station, color: Color(0xFF2A9D8F), size: 32),
                    ),
                  ),
                Marker(point: point, width: 46, height: 46, child: const Icon(Icons.directions_car, color: Colors.deepPurple, size: 38)),
              ]),
            ],
          ),
          if (_tried && _chargers.isEmpty && !_loading)
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    es ? 'Sin cargadores mapeados cerca' : 'No mapped chargers nearby',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}"""

if s.count(old)!=1:
    print(f"ERROR FullMapScreen: ancla x{s.count(old)}"); sys.exit(1)
s = s.replace(old, new)
open(p,'w',encoding='utf-8').write(s)
print("OK  FullMapScreen con cargadores (Overpass) + navegacion movil")
PYEOF

echo "LISTO. Compila: flutter build apk --release"
