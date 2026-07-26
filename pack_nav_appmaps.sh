#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
K=android/app/src/main/kotlin/com/txurtxil/lpb10
M=android/app/src/main/AndroidManifest.xml
cp $M backups_widget/AndroidManifest.xml.bak_$TS
cp $K/ChargersScreen.kt backups_widget/ChargersScreen.kt.bak_$TS
echo "[i] Backups en *.bak_$TS"

# ===== 1. Manifest: LMB10 deja de declararse app de mapas =====
python3 - <<'PYEOF'
import io, sys
m = "android/app/src/main/AndroidManifest.xml"
s = io.open(m, encoding='utf-8').read()
old = '                <category android:name="android.intent.category.APP_MAPS" />\n'
if s.count(old) != 1:
    sys.exit("ABORT: ancla APP_MAPS x%d" % s.count(old))
s = s.replace(old, "", 1)
io.open(m, 'w', encoding='utf-8').write(s)
print("[ok] manifest: APP_MAPS retirado (LMB10 ya no recibe intents de navegacion)")
PYEOF

# ===== 2. URI: volver al geo: con destino, que el host SI aceptaba =====
python3 - <<'PYEOF'
import io, sys
p = "android/app/src/main/kotlin/com/txurtxil/lpb10/ChargersScreen.kt"
s = io.open(p, encoding='utf-8').read()
old = '"google.navigation:q=" + c.lat + "," + c.lon'
if s.count(old) != 1:
    sys.exit("ABORT: ancla uri x%d" % s.count(old))
new = '"geo:" + c.lat + "," + c.lon + "?q=" + c.lat + "," + c.lon + "(" + Uri.encode(c.name) + ")"'
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8').write(s)
print("[ok] ChargersScreen: URI geo con destino")
PYEOF

echo "[i] Verificacion:"
echo -n "  APP_MAPS fuera (0): "; grep -c "APP_MAPS" $M || true
echo -n "  NAVIGATION sigue (1): "; grep -c "androidx.car.app.category.NAVIGATION" $M
echo -n "  CAR_LAUNCHER sigue (1): "; grep -c "CAR_LAUNCHER" $M
echo -n "  URI geo con q (1): "; grep -c 'q=" + c.lat' $K/ChargersScreen.kt
