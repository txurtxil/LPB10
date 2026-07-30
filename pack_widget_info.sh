set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
K=android/app/src/main/kotlin/com/txurtxil/lpb10
cp "$K/QuickWidgetProvider.kt" "backups_widget/QuickWidgetProvider.kt.bak_$TS"
echo "Backup: backups_widget/QuickWidgetProvider.kt.bak_$TS"

python3 - << 'PYEOF'
import sys
p = 'android/app/src/main/kotlin/com/txurtxil/lpb10/QuickWidgetProvider.kt'
s = open(p, encoding='utf-8').read()

ini = s.find('        val estado = when (locked) {')
fin = s.find('        var pintado = false')
if ini < 0 or fin < 0 or fin < ini:
    print("ABORTA: no encuentro el bloque de textos"); sys.exit(1)

nuevo = '''        // LINEA 1: lo que esta pasando AHORA. No se repite lo que ya da el
        // widget grande (autonomia, consumo, totales): aqui solo va lo que
        // sirve para decidir si hay que hacer algo con el coche.
        val temp = p.getString("batteryTemp", null)
        val tempTs = p.getString("batteryTempTs", null)?.toLongOrNull()
        val restante = p.getString("chargeRemainTime", null)?.toIntOrNull()
        val l1 = when {
            charging == "1" -> {
                val t = StringBuilder("Cargando")
                if (!kw.isNullOrEmpty()) t.append("  ").append(kw).append(" kW")
                if (restante != null && restante > 0) {
                    t.append("  ·  completa en ")
                    t.append(if (restante >= 60)
                        (restante / 60).toString() + " h " + (restante % 60).toString() + " min"
                        else restante.toString() + " min")
                }
                t.toString()
            }
            !temp.isNullOrEmpty() -> {
                val edad = if (tempTs != null) {
                    val h = (System.currentTimeMillis() - tempTs) / 3600000L
                    if (h >= 1L) "  (hace " + h + " h)" else ""
                } else ""
                "Bateria " + temp + "\\u00B0" + edad
            }
            else -> ""
        }
        if (l1.isNotEmpty()) {
            v.setTextViewText(R.id.qw_info, l1)
            v.setViewVisibility(R.id.qw_info, View.VISIBLE)
        } else {
            v.setViewVisibility(R.id.qw_info, View.GONE)
        }

        // LINEA 2: ruedas. El rango entre la mas alta y la mas baja delata una
        // perdida lenta antes de que el coche llegue a avisar.
        val kpa = (p.getString("tireKpa", "") ?: "").split("|").mapNotNull { it.toIntOrNull() }
        val l2 = if (kpa.size >= 2) {
            val lo = kpa.min() / 100f
            val hi = kpa.max() / 100f
            if (kpa.min() == kpa.max())
                "Ruedas " + String.format("%.2f", lo).replace('.', ',') + " bar"
            else
                "Ruedas " + String.format("%.2f", lo).replace('.', ',') + " - " +
                String.format("%.2f", hi).replace('.', ',') + " bar"
        } else ""
        if (l2.isNotEmpty()) {
            v.setTextViewText(R.id.qw_info2, l2)
            v.setViewVisibility(R.id.qw_info2, View.VISIBLE)
        } else {
            v.setViewVisibility(R.id.qw_info2, View.GONE)
        }

        v.setViewVisibility(R.id.qw_info3, View.GONE)

        // Aviso solo cuando hay algo que avisar. Un widget que siempre dice
        // "todo bien" deja de mirarse.
        val avisos = ArrayList<String>()
        val ruedasMal = (p.getString("tireAlerts", "") ?: "").split("|").filter { it.isNotEmpty() }
        if (ruedasMal.isNotEmpty()) avisos.add("Presion: " + ruedasMal.joinToString(", "))
        if (locked == "0") avisos.add("El coche esta abierto")
        if (avisos.isEmpty()) {
            v.setViewVisibility(R.id.qw_alert, View.GONE)
        } else {
            v.setTextViewText(R.id.qw_alert, "\\u26A0  " + avisos.joinToString("  ·  "))
            v.setViewVisibility(R.id.qw_alert, View.VISIBLE)
        }

'''
s = s[:ini] + nuevo + s[fin:]

# el candado cerrado ya no se pinta como texto: va al titulo
s = s.replace('v.setTextViewText(R.id.qw_title,\n            "LMB10" + (if (charging == "1") "  \\u26A1" else ""))',
 'v.setTextViewText(R.id.qw_title,\n            "LMB10" + (if (charging == "1") "  \\u26A1" else "") +\n            (if (locked == "1") "  \\uD83D\\uDD12" else ""))')

open(p, 'w', encoding='utf-8').write(s)
d = (s.count('('), s.count(')'), s.count('{'), s.count('}'))
print("  parentesis %d/%d  llaves %d/%d" % d)
if d[0] != d[1] or d[2] != d[3]:
    print("ABORTA: descuadre"); sys.exit(1)
print("OK")
PYEOF

echo "--- verificaciones ---"
echo -n "rangoTxt eliminado (debe 0): "; grep -c 'rangoTxt' "$K/QuickWidgetProvider.kt" || true
echo -n "tireKpa usado: "; grep -c 'tireKpa' "$K/QuickWidgetProvider.kt"
echo
echo "--- compilando ---"
flutter build apk --release 2>&1 | tail -5

echo
echo "=== para el siguiente paso: la direccion del coche ==="
grep -rn "reverseGeocode\|nominatim\|Nominatim\|'address'\|direccion\|placeName" lib/*.dart | grep -v bak | head -20
