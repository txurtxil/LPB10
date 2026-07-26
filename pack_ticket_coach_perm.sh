#!/bin/bash
# ============================================================================
# LMB10 - El TICKET y el COACH leen del ARCHIVO PERMANENTE (trips.jsonl) en vez
# del store capado a 200 -> muestran los dias reales, no "--". Fallback al store.
# ============================================================================
set -e
[ -f lib/main.dart ] || { echo "ERROR: raiz"; exit 1; }
mkdir -p backups_widget
cp lib/ticket_printer.dart backups_widget/ticket_printer.dart.bak_perm
cp lib/efficiency_coach.dart backups_widget/efficiency_coach.dart.bak_perm

python3 << 'PYEOF'
import sys
p = 'lib/ticket_printer.dart'
s = open(p, encoding='utf-8').read()

if "import 'package:path_provider/path_provider.dart';" not in s:
    anc = "import 'package:share_plus/share_plus.dart';"
    if s.count(anc)!=1: print(f"ERROR import: x{s.count(anc)}"); sys.exit(1)
    s = s.replace(anc, anc + "\nimport 'package:path_provider/path_provider.dart';")

anchor = "Future<List<DayEff>> _computeDays(DateTime from, DateTime to) async {"
helper = """Future<List<({int ts, int km, double soc})>> _readPermanentTripsT() async {
  final out = <({int ts, int km, double soc})>[];
  try {
    final base = await getApplicationDocumentsDirectory();
    final f = File('${base.path}/lmb10_history/trips.jsonl');
    if (!await f.exists()) return out;
    for (final line in await f.readAsLines()) {
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

Future<List<DayEff>> _computeDays(DateTime from, DateTime to) async {"""
if s.count(anchor)!=1: print(f"ERROR helper ticket: x{s.count(anchor)}"); sys.exit(1)
s = s.replace(anchor, helper)

old_tr = "  final tripRaw = await _tStorage.read(key: 'lm_trip_points_v1');\n"
if s.count(old_tr)!=1: print(f"ERROR tripRaw ticket: x{s.count(old_tr)}"); sys.exit(1)
s = s.replace(old_tr, "")

old = """  final points = <({int ts, int km, double soc})>[];
  if (tripRaw != null) {
    for (final e in (json.decode(tripRaw) as List)) {
      final m = Map<String, dynamic>.from(e as Map);
      points.add((ts: m['ts'] as int, km: m['km'] as int, soc: (m['soc'] as num).toDouble()));
    }
  }"""
new = """  var points = await _readPermanentTripsT();
  if (points.isEmpty) {
    final tripRaw = await _tStorage.read(key: 'lm_trip_points_v1');
    if (tripRaw != null) {
      for (final e in (json.decode(tripRaw) as List)) {
        final m = Map<String, dynamic>.from(e as Map);
        points.add((ts: m['ts'] as int, km: m['km'] as int, soc: (m['soc'] as num).toDouble()));
      }
    }
  }"""
if s.count(old)!=1: print(f"ERROR carga ticket: x{s.count(old)}"); sys.exit(1)
s = s.replace(old, new)
open(p,'w',encoding='utf-8').write(s)
print("OK  ticket_printer.dart: lee del archivo permanente")
PYEOF

python3 << 'PYEOF'
import sys
p = 'lib/efficiency_coach.dart'
s = open(p, encoding='utf-8').read()

if "import 'package:path_provider/path_provider.dart';" not in s:
    anc = "import 'package:flutter_secure_storage/flutter_secure_storage.dart';"
    if s.count(anc)!=1: print(f"ERROR import coach: x{s.count(anc)}"); sys.exit(1)
    s = s.replace(anc, "import 'dart:io';\n\n" + anc + "\nimport 'package:path_provider/path_provider.dart';")

anchor = "  Future<void> _compute() async {"
helper = """  Future<List<({int ts, int km, double soc})>> _readPermanentTrips() async {
    final out = <({int ts, int km, double soc})>[];
    try {
      final base = await getApplicationDocumentsDirectory();
      final f = File('${base.path}/lmb10_history/trips.jsonl');
      if (!await f.exists()) return out;
      for (final line in await f.readAsLines()) {
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

  Future<void> _compute() async {"""
if s.count(anchor)!=1: print(f"ERROR helper coach: x{s.count(anchor)}"); sys.exit(1)
s = s.replace(anchor, helper)

old = """      final tripRaw = await _storage.read(key: 'lm_trip_points_v1');
      final chargeRaw = await _storage.read(key: 'lm_charge_history_v1');
      final since = DateTime.now().subtract(const Duration(days: 30));

      double km = 0, drop = 0;
      if (tripRaw != null) {
        final pts = (json.decode(tripRaw) as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((m) =>
                DateTime.fromMillisecondsSinceEpoch(m['ts'] as int).isAfter(since))
            .toList();
        for (var i = 1; i < pts.length; i++) {
          final kmD = ((pts[i]['km'] as int) - (pts[i - 1]['km'] as int)).toDouble();
          final socD = (pts[i - 1]['soc'] as num).toDouble() -
              (pts[i]['soc'] as num).toDouble();
          if (kmD > 0 && socD > 0) {
            km += kmD;
            drop += socD;
          }
        }
      }"""
new = """      final chargeRaw = await _storage.read(key: 'lm_charge_history_v1');
      final since = DateTime.now().subtract(const Duration(days: 30));

      double km = 0, drop = 0;
      var perm = await _readPermanentTrips();
      if (perm.isEmpty) {
        final tripRaw = await _storage.read(key: 'lm_trip_points_v1');
        if (tripRaw != null) {
          for (final e in (json.decode(tripRaw) as List)) {
            final m = Map<String, dynamic>.from(e as Map);
            perm.add((ts: m['ts'] as int, km: m['km'] as int, soc: (m['soc'] as num).toDouble()));
          }
        }
      }
      final pts = perm
          .where((p) => DateTime.fromMillisecondsSinceEpoch(p.ts).isAfter(since))
          .toList();
      for (var i = 1; i < pts.length; i++) {
        final kmD = (pts[i].km - pts[i - 1].km).toDouble();
        final socD = pts[i - 1].soc - pts[i].soc;
        if (kmD > 0 && socD > 0) {
          km += kmD;
          drop += socD;
        }
      }"""
if s.count(old)!=1: print(f"ERROR carga coach: x{s.count(old)}"); sys.exit(1)
s = s.replace(old, new)
open(p,'w',encoding='utf-8').write(s)
print("OK  efficiency_coach.dart: lee del archivo permanente")
PYEOF

echo "LISTO. Compila: flutter build apk --release"
