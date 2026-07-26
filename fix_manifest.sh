#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
M=android/app/src/main/AndroidManifest.xml

echo "### ESTADO ACTUAL"
grep -n "uses-permission android:name=\"androidx.car.app" "$M"

cp -v "$M" "backups_widget/AndroidManifest.xml.bak_$TS"

cat > /tmp/fix_manifest.py << 'PYEOF'
import sys, os
M = os.path.expanduser('~/LP10/android/app/src/main/AndroidManifest.xml')
OLD = '    <uses-permission android:name="androidx.car.app.MAP_TEMPLATES" />\n'
NEW = ('    <uses-permission android:name="androidx.car.app.MAP_TEMPLATES" />\n'
       '    <uses-permission android:name="androidx.car.app.NAVIGATION_TEMPLATES" />\n')
s = open(M, encoding='utf-8').read()
if 'NAVIGATION_TEMPLATES' in s:
    print("YA ESTABA. No se toca nada."); sys.exit(0)
n = s.count(OLD)
print("ancla -> %d ocurrencias" % n)
if n != 1:
    print("ABORTA: se esperaba exactamente 1"); sys.exit(1)
open(M, 'w', encoding='utf-8').write(s.replace(OLD, NEW, 1))
print("ESCRITO")
PYEOF
python3 /tmp/fix_manifest.py

echo
echo "### DESPUES"
grep -n "uses-permission android:name=\"androidx.car.app" "$M"
