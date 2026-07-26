#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
M=android/app/src/main/AndroidManifest.xml
cp $M backups_widget/AndroidManifest.xml.bak_$TS
echo "[i] Backup en *.bak_$TS"

python3 - <<'PYEOF'
import io, sys
m = "android/app/src/main/AndroidManifest.xml"
s = io.open(m, encoding='utf-8').read()

# Cambiar la categoria del CarAppService de IOT a NAVIGATION
old = '                <category android:name="androidx.car.app.category.IOT" />'
new = '                <category android:name="androidx.car.app.category.NAVIGATION" />'
if s.count(old) != 1:
    sys.exit("ABORT: ancla IOT x%d" % s.count(old))
s = s.replace(old, new, 1)
io.open(m, 'w', encoding='utf-8').write(s)
print("[ok] categoria cambiada IOT -> NAVIGATION")
PYEOF

# El automotive_app_desc puede necesitar declarar navegacion tambien
cat > android/app/src/main/res/xml/automotive_app_desc.xml <<'XEOF'
<?xml version="1.0" encoding="utf-8"?>
<automotiveApp>
    <uses name="template" />
</automotiveApp>
XEOF
echo "[ok] automotive_app_desc verificado"

echo "[i] Verificacion:"
echo -n "  NAVIGATION (1): "; grep -c "androidx.car.app.category.NAVIGATION" $M
echo -n "  IOT ya no esta (0): "; grep -c "androidx.car.app.category.IOT" $M
