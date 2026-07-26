#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
K=android/app/src/main/kotlin/com/txurtxil/lpb10
cp $K/CarMainScreen.kt backups_widget/CarMainScreen.kt.bak_$TS
echo "[i] Backup en *.bak_$TS"

python3 - <<'PYEOF'
import io, sys
p = "android/app/src/main/kotlin/com/txurtxil/lpb10/CarMainScreen.kt"
s = io.open(p, encoding='utf-8').read()

# Cambiar el titulo del hub para incluir la version del BuildConfig
old = '''            .setTitle("LMB10")'''
new = '''            .setTitle("LMB10 v" + BuildConfig.VERSION_NAME)'''
if s.count(old) != 1:
    sys.exit("ABORT: ancla setTitle LMB10 x%d" % s.count(old))
s = s.replace(old, new, 1)

# Asegurar el import de BuildConfig
if "import com.txurtxil.lpb10.BuildConfig" not in s and "BuildConfig" in s:
    # insertar tras el package
    s = s.replace("package com.txurtxil.lpb10\n",
                  "package com.txurtxil.lpb10\nimport com.txurtxil.lpb10.BuildConfig\n", 1)

io.open(p, 'w', encoding='utf-8').write(s)
print("[ok] hub: titulo con version del BuildConfig")
PYEOF

echo -n "  version en titulo (1): "; grep -c "VERSION_NAME" $K/CarMainScreen.kt

# Verificar que BuildConfig esta habilitado en gradle
echo -n "  buildConfig habilitado en gradle: "
grep -q "buildConfig = true\|buildConfig true" android/app/build.gradle.kts && echo "SI" || echo "NO - hay que habilitarlo"
