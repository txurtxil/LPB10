#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
cp android/app/build.gradle.kts backups_widget/build.gradle.kts.bak_$TS
echo "[i] Backup en *.bak_$TS"

python3 - <<'PYEOF'
import io, sys
g = "android/app/build.gradle.kts"
s = io.open(g, encoding='utf-8').read()

if "key.properties" in s:
    sys.exit("[skip] firma ya configurada, nada que hacer")

# 1. imports arriba
a = "plugins {"
if s.count(a) != 1: sys.exit("ABORT: ancla plugins x%d" % s.count(a))
s = s.replace(a, "import java.util.Properties\nimport java.io.FileInputStream\n\nplugins {", 1)

# 2. carga de key.properties antes de android{
a = 'android {\n    namespace = "com.txurtxil.lpb10"'
if s.count(a) != 1: sys.exit("ABORT: ancla android x%d" % s.count(a))
s = s.replace(a,
'''val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.txurtxil.lpb10"''', 1)

# 3. signingConfigs antes de buildTypes
a = "    buildTypes {"
if s.count(a) != 1: sys.exit("ABORT: ancla buildTypes x%d" % s.count(a))
s = s.replace(a,
'''    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }
    buildTypes {''', 1)

# 4. usar la firma release si existe el keystore
a = '            signingConfig = signingConfigs.getByName("debug")'
if s.count(a) != 1: sys.exit("ABORT: ancla signingConfig x%d" % s.count(a))
s = s.replace(a,
'''            signingConfig = if (keystorePropertiesFile.exists())
                signingConfigs.getByName("release")
            else signingConfigs.getByName("debug")''', 1)

io.open(g, 'w', encoding='utf-8').write(s)
print("[ok] firma release configurada en build.gradle.kts")
PYEOF

echo "[i] Verificacion:"
echo -n "  key.properties en gradle: "; grep -c "key.properties" android/app/build.gradle.kts
echo -n "  signingConfigs release: "; grep -c 'create("release")' android/app/build.gradle.kts
echo -n "  keystore existe: "; ls ~/lmb10-release.jks >/dev/null 2>&1 && echo "SI" || echo "NO - ejecuta el keytool"
echo -n "  key.properties existe: "; ls android/key.properties >/dev/null 2>&1 && echo "SI" || echo "NO - crealo con tu password"
