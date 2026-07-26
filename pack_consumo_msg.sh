#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
K=android/app/src/main/kotlin/com/txurtxil/lpb10
cp $K/ConsumoScreen.kt backups_widget/ConsumoScreen.kt.bak_$TS
echo "[i] Backup en *.bak_$TS"

python3 - <<'PYEOF'
import io, sys
p = "android/app/src/main/kotlin/com/txurtxil/lpb10/ConsumoScreen.kt"
s = io.open(p, encoding='utf-8').read()

# Tras el bloque de barras, si no habia dias con datos, mostrar mensaje informativo
anchor = '''        val allDays = daysRaw.split(",").filter { it.contains(":") }
        val daysWithData = allDays.filter { it.substringAfter(":").toFloatOrNull() != null }
        if (daysWithData.isNotEmpty()) {'''
new = '''        val allDays = daysRaw.split(",").filter { it.contains(":") }
        val daysWithData = allDays.filter { it.substringAfter(":").toFloatOrNull() != null }
        if (daysWithData.isEmpty()) {
            list.addItem(
                Row.Builder()
                    .setTitle(if (es) "Por dia" else "Per day")
                    .addText(if (es)
                        "Aun no hay datos diarios. Se registraran con el uso."
                        else "No daily data yet. It will build up as you drive.")
                    .build()
            )
        }
        if (daysWithData.isNotEmpty()) {'''
if s.count(anchor) != 1:
    sys.exit("ABORT: ancla x%d" % s.count(anchor))
s = s.replace(anchor, new, 1)
io.open(p, 'w', encoding='utf-8').write(s)
print("[ok] ConsumoScreen: mensaje cuando no hay datos diarios")
PYEOF

echo -n "  mensaje sin datos (1): "; grep -c "Se registraran con el uso" $K/ConsumoScreen.kt
