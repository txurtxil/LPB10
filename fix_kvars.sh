#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10

echo "### LINEAS AFECTADAS"
sed -n '348,364p' lib/energy_cost.dart

cp -v lib/energy_cost.dart "backups_widget/energy_cost.dart.bak_$(date +%Y%m%d_%H%M%S)"

python3 - << 'PYEOF'
import os, sys
p = os.path.expanduser('~/LP10/lib/energy_cost.dart')
s = open(p, encoding='utf-8').read()
pares = [
    ("eur(kHoy)", "eur(tHoy.eur)"),
    ("eur(k7)",   "eur(t7.eur)"),
    ("eur(kMes)", "eur(tMes.eur)"),
]
for old, new in pares:
    n = s.count(old)
    print("  %-12s -> %d ocurrencias" % (old, n))
    if n != 1:
        print("  ABORTA: se esperaba exactamente 1"); sys.exit(1)
    s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print("ESCRITO")
PYEOF

echo
echo "### VERIFICACION"
grep -n "kHoy\|k7\|kMes" lib/energy_cost.dart || echo "(sin variables huerfanas, correcto)"
echo
echo "### ANALYZE"
flutter analyze lib/energy_cost.dart 2>&1 | grep -E "error •" | head -10 || echo "(limpio)"
