set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
M=android/app/src/main/AndroidManifest.xml
cp "$M" "backups_widget/AndroidManifest.xml.bak_$TS"
echo "Backup: backups_widget/AndroidManifest.xml.bak_$TS"

cat > /tmp/patch_poi.py << 'PYEOF'
import sys
import xml.etree.ElementTree as ET
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = '<category android:name="androidx.car.app.category.CHARGING" />'
new = '<category android:name="androidx.car.app.category.POI" />'
n = s.count(old)
if n != 1:
    print("ABORTA: ancla CHARGING aparece %d veces (esperado 1)" % n)
    sys.exit(1)
s = s.replace(old, new)
open(p, 'w', encoding='utf-8').write(s)
try:
    ET.fromstring(s)
except Exception as e:
    print("ABORTA: XML mal formado ->", e)
    sys.exit(1)
malo = 0
for needle, esperado in [('category.POI', 1), ('category.CHARGING', 0),
                         ('category.NAVIGATION', 0), ('ACCESS_SURFACE', 0),
                         ('NAVIGATION_TEMPLATES', 0), ('MAP_TEMPLATES', 1)]:
    c = s.count(needle)
    print("  %-24s %d (esperado %d)" % (needle, c, esperado))
    if c != esperado:
        malo = 1
if malo:
    print("ABORTA: recuento incorrecto")
    sys.exit(1)
print("XML valido, recuentos OK")
PYEOF

python3 /tmp/patch_poi.py "$M"
grep -n 'car.app' "$M"
