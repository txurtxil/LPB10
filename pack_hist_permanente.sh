#!/bin/bash
# ============================================================================
# LMB10 - pack_hist_permanente.sh
#   El grafico del widget lee los puntos del ARCHIVO PERMANENTE (trips.jsonl,
#   sin limite) en vez del store capado a 200. Asi los dias pasados que se
#   cayeron del cap (p. ej. dia 11) vuelven a tener datos y no salen "--".
#   Fallback: si el archivo permanente no existe/esta vacio, usa el store.
# Ejecutar desde la raiz: bash pack_hist_permanente.sh
# ============================================================================
set -e
[ -f lib/main.dart ] || { echo "ERROR: raiz del proyecto"; exit 1; }
mkdir -p backups_widget
cp lib/widget_chart.dart backups_widget/widget_chart.dart.bak_hist

python3 << 'PYEOF'
import sys
p = 'lib/widget_chart.dart'
s = open(p, encoding='utf-8').read()

anchor_fn = "Future<Map<String, String>> buildWidgetExtras("
helper = """/// Lee los puntos de viaje del archivo permanente (Documents/lmb10_history/
/// trips.jsonl), que guarda TODO sin el limite de 200 del store rapido.
/// Devuelve lista vacia si no existe o no se puede leer.
Future<List<({int ts, int km, double soc})>> _readPermanentTrips() async {
  final out = <({int ts, int km, double soc})>[];
  try {
    final base = await getApplicationDocumentsDirectory();
    final f = File('${base.path}/lmb10_history/trips.jsonl');
    if (!await f.exists()) return out;
    final lines = await f.readAsLines();
    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) continue;
      try {
        final m = Map<String, dynamic>.from(json.decode(t) as Map);
        if (m['ts'] is int && m['km'] is int && m['soc'] is num) {
          out.add((ts: m['ts'] as int, km: m['km'] as int, soc: (m['soc'] as num).toDouble()));
        }
      } catch (_) {}
    }
    out.sort((a, b) => a.ts.compareTo(b.ts));
  } catch (_) {}
  return out;
}

Future<Map<String, String>> buildWidgetExtras("""
if s.count(anchor_fn)!=1:
    print(f"ERROR helper: ancla x{s.count(anchor_fn)}"); sys.exit(1)
s = s.replace(anchor_fn, helper)

old = """    final tripRaw = await _wcStorage.read(key: _kTripKey);
    final chargeRaw = await _wcStorage.read(key: _kChargeKey);

    final points = <({int ts, int km, double soc})>[];
    if (tripRaw != null) {
      for (final e in (json.decode(tripRaw) as List)) {
        final m = Map<String, dynamic>.from(e as Map);
        points.add((
          ts: m['ts'] as int,
          km: m['km'] as int,
          soc: (m['soc'] as num).toDouble(),
        ));
      }
    }"""
new = """    final chargeRaw = await _wcStorage.read(key: _kChargeKey);

    // Fuente de puntos: PRIMERO el archivo permanente (sin cap). Si esta vacio
    // (p. ej. recien instalado), se cae al store rapido capado a 200.
    var points = await _readPermanentTrips();
    if (points.isEmpty) {
      final tripRaw = await _wcStorage.read(key: _kTripKey);
      if (tripRaw != null) {
        for (final e in (json.decode(tripRaw) as List)) {
          final m = Map<String, dynamic>.from(e as Map);
          points.add((
            ts: m['ts'] as int,
            km: m['km'] as int,
            soc: (m['soc'] as num).toDouble(),
          ));
        }
      }
    }"""
if s.count(old)!=1:
    print(f"ERROR carga: ancla x{s.count(old)}"); sys.exit(1)
s = s.replace(old, new)
open(p,'w',encoding='utf-8').write(s)
print("OK  widget_chart.dart: lee del archivo permanente (fallback al store)")
PYEOF

echo "LISTO. Compila: flutter build apk --release"
