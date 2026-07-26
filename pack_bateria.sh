#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
K=android/app/src/main/kotlin/com/txurtxil/lpb10
cp android/app/build.gradle.kts backups_widget/build.gradle.kts.bak_$TS
cp lib/main.dart backups_widget/main.dart.bak_$TS
cp $K/BatteryScreen.kt backups_widget/BatteryScreen.kt.bak_$TS
echo "[i] Backups en *.bak_$TS"

# ===== 1. Habilitar BuildConfig en gradle =====
python3 - <<'PYEOF'
import io, sys
g = "android/app/build.gradle.kts"
s = io.open(g, encoding='utf-8').read()
if "buildConfig = true" in s:
    print("[skip] buildConfig ya habilitado")
else:
    # Añadir buildFeatures { buildConfig = true } dentro de android { }
    anchor = 'android {\n    namespace = "com.txurtxil.lpb10"'
    if s.count(anchor) != 1:
        sys.exit("ABORT: ancla android gradle x%d" % s.count(anchor))
    s = s.replace(anchor,
        'android {\n    namespace = "com.txurtxil.lpb10"\n    buildFeatures {\n        buildConfig = true\n    }', 1)
    io.open(g, 'w', encoding='utf-8').write(s)
    print("[ok] gradle: buildConfig habilitado")
PYEOF

# ===== 2. Dart: guardar temp bateria y tiempo de carga a prefs =====
python3 - <<'PYEOF'
import io, sys
d = "lib/main.dart"
s = io.open(d, encoding='utf-8').read()

anchor = "  await HomeWidget.saveWidgetData<String>('interiorTemp', s.raw['interiorTemp']?.toString() ?? '');"
if s.count(anchor) != 1:
    sys.exit("ABORT: ancla interiorTemp x%d" % s.count(anchor))
add = anchor + '''
  await HomeWidget.saveWidgetData<String>('batteryTemp', s.raw['minBatteryTemp']?.toString() ?? '');
  await HomeWidget.saveWidgetData<String>('chargeRemainTime', s.raw['chargeRemainTime']?.toString() ?? '');'''
s = s.replace(anchor, add, 1)
io.open(d, 'w', encoding='utf-8').write(s)
print("[ok] Dart: batteryTemp + chargeRemainTime guardados a prefs")
PYEOF

# ===== 3. BatteryScreen: mostrar temp bateria y tiempo de carga =====
python3 - <<'PYEOF'
import io, sys
p = "android/app/src/main/kotlin/com/txurtxil/lpb10/BatteryScreen.kt"
s = io.open(p, encoding='utf-8').read()

# Leer los nuevos datos
old_reads = '''        val temp = p.getString("interiorTemp", null)'''
new_reads = '''        val temp = p.getString("interiorTemp", null)
        val batTemp = p.getString("batteryTemp", null)
        val chargeMin = p.getString("chargeRemainTime", null)?.toIntOrNull()'''
if s.count(old_reads) != 1:
    sys.exit("ABORT: ancla reads x%d" % s.count(old_reads))
s = s.replace(old_reads, new_reads, 1)

# Añadir filas: temp bateria y tiempo de carga (antes del return)
old_ret = '''        return PaneTemplate.Builder(pane.build())
            .setTitle("Bateria")
            .setHeaderAction(Action.BACK)
            .build()'''
new_ret = '''        if (!batTemp.isNullOrEmpty()) {
            pane.addRow(
                Row.Builder()
                    .setTitle("Temp. bateria")
                    .addText(batTemp + " °C")
                    .build()
            )
        }
        if (chargeMin != null && chargeMin > 0) {
            val h = chargeMin / 60
            val m = chargeMin % 60
            val txt = if (h > 0) h.toString() + " h " + m + " min" else m.toString() + " min"
            pane.addRow(
                Row.Builder()
                    .setTitle("Carga restante")
                    .addText(txt)
                    .build()
            )
        }
        return PaneTemplate.Builder(pane.build())
            .setTitle("Bateria")
            .setHeaderAction(Action.BACK)
            .build()'''
if s.count(old_ret) != 1:
    sys.exit("ABORT: ancla return x%d" % s.count(old_ret))
s = s.replace(old_ret, new_ret, 1)
io.open(p, 'w', encoding='utf-8').write(s)
print("[ok] BatteryScreen: temp bateria + tiempo de carga")
PYEOF

echo "[i] Verificacion:"
echo -n "  buildConfig gradle (1): "; grep -c "buildConfig = true" android/app/build.gradle.kts
echo -n "  batteryTemp en Dart (1): "; grep -c "'batteryTemp'" lib/main.dart
echo -n "  temp bateria en pantalla (1): "; grep -c "Temp. bateria" $K/BatteryScreen.kt
echo -n "  carga restante (1): "; grep -c "Carga restante" $K/BatteryScreen.kt
echo -n "  bug \$ Dart (0): "; grep -c '\\\$' lib/main.dart || true
