#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
cp lib/backup_helper.dart backups_widget/backup_helper.dart.bak_$TS
echo "[i] Backup en *.bak_$TS"

python3 - <<'PYEOF'
import io, sys
p = "lib/backup_helper.dart"
s = io.open(p, encoding='utf-8').read()

old = '''  static Future<Map<String, dynamic>> _collect() async {
    final docs = await getApplicationDocumentsDirectory();
    final out = <String, dynamic>{
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'trips': <String>[],
      'charges': <String>[],
    };
    try {
      final t = File('${docs.path}/lmb10_history/trips.jsonl');
      if (await t.exists()) out['trips'] = await t.readAsLines();
    } catch (_) {}
    try {
      final c = File('${docs.path}/lmb10_history/charges.jsonl');
      if (await c.exists()) out['charges'] = await c.readAsLines();
    } catch (_) {}
    return out;
  }'''

new = '''  static Future<Map<String, dynamic>> _collect() async {
    final docs = await getApplicationDocumentsDirectory();
    // Formato COMPATIBLE con importHistoryBackup(): claves tripPoints y
    // chargeSessions, con los mismos campos que espera el importador.
    final trips = <Map<String, dynamic>>[];
    final charges = <Map<String, dynamic>>[];
    try {
      final t = File('${docs.path}/lmb10_history/trips.jsonl');
      if (await t.exists()) {
        for (final line in await t.readAsLines()) {
          final s = line.trim();
          if (s.isEmpty) continue;
          try {
            final m = Map<String, dynamic>.from(json.decode(s) as Map);
            if (m['ts'] is int && m['km'] is int && m['soc'] is num) {
              trips.add({'ts': m['ts'], 'km': m['km'], 'soc': m['soc']});
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
    try {
      final c = File('${docs.path}/lmb10_history/charges.jsonl');
      if (await c.exists()) {
        for (final line in await c.readAsLines()) {
          final s = line.trim();
          if (s.isEmpty) continue;
          try {
            final m = Map<String, dynamic>.from(json.decode(s) as Map);
            if (m['startTs'] is int && m['startSoc'] is num) {
              charges.add({
                'startTs': m['startTs'],
                'endTs': m['endTs'],
                'startSoc': m['startSoc'],
                'endSoc': m['endSoc'],
              });
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
    return <String, dynamic>{
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'tripPoints': trips,
      'chargeSessions': charges,
    };
  }'''

if s.count(old) != 1:
    sys.exit("ABORT: ancla _collect x%d" % s.count(old))
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8').write(s)
print("[ok] backup_helper.dart: formato compatible con el importador")

for op,cl,n in [('(',')','par'),('{','}','lla')]:
    print("  diff %s = %d" % (n, s.count(op)-s.count(cl)))
PYEOF

echo "[i] Verificacion:"
echo -n "  usa tripPoints (1): "; grep -c "'tripPoints': trips" lib/backup_helper.dart
echo -n "  usa chargeSessions (1): "; grep -c "'chargeSessions': charges" lib/backup_helper.dart
echo -n "  ya no usa 'trips': lines (0): "; grep -c "out\['trips'\]" lib/backup_helper.dart || true
echo -n "  bug \$ (0): "; grep -c '\\\$' lib/backup_helper.dart || true

flutter analyze lib/backup_helper.dart 2>&1 | grep -E "error" | head
