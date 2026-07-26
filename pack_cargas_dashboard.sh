#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
cp lib/main.dart backups_widget/main.dart.bak_$TS
echo "[i] Backup en *.bak_$TS"

rm -rf /tmp/pruebatest; mkdir -p /tmp/pruebatest
cp lib/main.dart /tmp/pruebatest/main.dart

python3 - <<'PYEOF'
import io, sys
d = "/tmp/pruebatest/main.dart"
s = io.open(d, encoding='utf-8').read()

# Ancla dashboard CON la linea en blanco real
old_db = '''    final soc = s.preciseSoc ?? s.soc?.toDouble();
    if (soc == null) return;

    final wasCharging = _previousStatus?.isCharging ?? false;
    if (!wasCharging && s.isCharging) {
      await ChargeHistoryStore.startSession(soc);
    } else if (wasCharging && !s.isCharging) {
      await ChargeHistoryStore.endSession(soc);
    }'''
new_db = '''    final soc = s.preciseSoc ?? s.soc?.toDouble();
    if (soc == null) return;

    // Rescata cualquier sesion huerfana antes de la deteccion normal.
    await ChargeHistoryStore.reconcileOpenSession(
      isPluggedIn: s.isPluggedIn,
      chargeCompleted: s.chargeCompleted == true,
      currentSoc: soc,
    );
    final wasCharging = _previousStatus?.isCharging ?? false;
    if (!wasCharging && s.isCharging) {
      await ChargeHistoryStore.startSession(soc);
    } else if (wasCharging && !s.isCharging) {
      await ChargeHistoryStore.endSession(soc);
    }'''
if s.count(old_db) != 1:
    sys.exit("ABORT: ancla dashboard x%d" % s.count(old_db))
s = s.replace(old_db, new_db, 1)

io.open(d, 'w', encoding='utf-8').write(s)
for op,cl,n in [('(',')','par'),('{','}','lla')]:
    print("[dry] %s diff=%d" % (n, s.count(op)-s.count(cl)))
print("[dry] reconcile en dashboard:", s.count("reconcileOpenSession"))
print("[dry] OK")
PYEOF

python3 -c "
import io
o=io.open('lib/main.dart',encoding='utf-8').read()
n=io.open('/tmp/pruebatest/main.dart',encoding='utf-8').read()
for op,cl in [('(',')'),('{','}')]:
    assert (o.count(op)-o.count(cl))==(n.count(op)-n.count(cl)), 'DESCUADRE '+op
print('[dry] balance preservado')
"

echo "[i] Dry-run OK. Aplicando..."
cp /tmp/pruebatest/main.dart lib/main.dart
echo -n "  reconcile en dashboard (debe ser 1): "; grep -c "reconcileOpenSession" lib/main.dart
