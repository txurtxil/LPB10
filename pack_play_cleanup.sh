#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
K=android/app/src/main/kotlin/com/txurtxil/lpb10
cp android/app/src/main/AndroidManifest.xml backups_widget/AndroidManifest.xml.bak_$TS
cp android/app/build.gradle.kts backups_widget/build.gradle.kts.bak_$TS
cp $K/LMB10CarAppService.kt backups_widget/LMB10CarAppService.kt.bak_$TS
echo "[i] Backups en *.bak_$TS"

# --- 1. Manifest: dejar SOLO el servicio IOT
python3 - <<'PYEOF'
import io, sys, re
m = "android/app/src/main/AndroidManifest.xml"
s = io.open(m, encoding='utf-8').read()
for cat in ["Navigation", "Poi", "Weather"]:
    pat = re.compile(
        r'\s*<service\s+android:name="\.LMB10CarService' + cat + r'"[\s\S]*?</service>')
    n = len(pat.findall(s))
    if n != 1:
        sys.exit("ABORT: servicio %s aparece %d veces" % (cat, n))
    s = pat.sub("", s)
io.open(m, 'w', encoding='utf-8').write(s)
print("[ok] manifest: solo IOT")
PYEOF

# --- 2. Borrar las clases de categoria extra
rm -f $K/LMB10CarServiceNavigation.kt $K/LMB10CarServicePoi.kt $K/LMB10CarServiceWeather.kt
echo "[ok] clases extra eliminadas"

# --- 3. Validador de produccion (solo hosts oficiales)
python3 - <<'PYEOF'
import io, sys
p = "android/app/src/main/kotlin/com/txurtxil/lpb10/LMB10CarAppService.kt"
s = io.open(p, encoding='utf-8').read()
old = """    override fun createHostValidator(): HostValidator =
        HostValidator.ALLOW_ALL_HOSTS_VALIDATOR"""
new = """    override fun createHostValidator(): HostValidator =
        if (applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE != 0) {
            HostValidator.ALLOW_ALL_HOSTS_VALIDATOR
        } else {
            HostValidator.Builder(applicationContext)
                .addAllowedHosts(androidx.car.app.R.array.hosts_allowlist_sample)
                .build()
        }"""
if s.count(old) != 1:
    sys.exit("ABORT: ancla validator x%d" % s.count(old))
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8').write(s)
print("[ok] validador de produccion (allow-all solo en debug)")
PYEOF

# --- 4. Firma de release en build.gradle.kts
python3 - <<'PYEOF'
import io, sys
g = "android/app/build.gradle.kts"
s = io.open(g, encoding='utf-8').read()
if "key.properties" in s:
    print("[skip] firma ya configurada")
else:
    old_plug = """plugins {"""
    new_plug = """import java.util.Properties
import java.io.FileInputStream

plugins {"""
    if s.count(old_plug) != 1: sys.exit("ABORT: ancla plugins")
    s = s.replace(old_plug, new_plug, 1)

    old_android = """android {
    namespace = "com.txurtxil.lpb10\""""
    new_android = """val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.txurtxil.lpb10\""""
    if s.count(old_android) != 1: sys.exit("ABORT: ancla android")
    s = s.replace(old_android, new_android, 1)

    old_bt = """    buildTypes {
        release {
            // TODO: Add your own signing config for the release
build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }"""
    new_bt = """    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }
    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists())
                signingConfigs.getByName("release")
            else signingConfigs.getByName("debug")
        }
    }"""
    if s.count(old_bt) != 1: sys.exit("ABORT: ancla buildTypes x%d" % s.count(old_bt))
    s = s.replace(old_bt, new_bt, 1)
    io.open(g, 'w', encoding='utf-8').write(s)
    print("[ok] firma release configurada")
PYEOF

echo "[i] Verificacion:"
echo -n "  servicios CarApp en manifest (debe ser 1): "; grep -c "androidx.car.app.CarAppService" android/app/src/main/AndroidManifest.xml
echo -n "  clases extra (debe ser 0): "; ls $K/LMB10CarService*.kt 2>/dev/null | wc -l
echo -n "  allow-all solo debug: "; grep -c "FLAG_DEBUGGABLE" $K/LMB10CarAppService.kt
echo -n "  key.properties en gradle: "; grep -c "key.properties" android/app/build.gradle.kts

echo
echo "[OK] Ahora compila el App Bundle (formato que exige Play):"
echo "  flutter build appbundle --release 2>&1 | tail -6"
