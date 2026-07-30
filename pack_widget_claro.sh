set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
K=android/app/src/main/kotlin/com/txurtxil/lpb10
D=android/app/src/main/res/drawable
cp android/app/src/main/res/layout/quick_widget.xml "backups_widget/quick_widget.xml.bak_$TS"
cp "$K/QuickWidgetProvider.kt" "backups_widget/QuickWidgetProvider.kt.bak_$TS"

cat > "$D/qw_bg.xml" << 'X'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#CFE6F7" />
    <corners android:radius="26dp" />
</shape>
X

cat > "$D/qw_btn.xml" << 'X'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#E9F5FE" />
    <corners android:radius="16dp" />
    <stroke android:width="1dp" android:color="#8FBEDF" />
</shape>
X

cat > "$D/qw_btn_warn.xml" << 'X'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <solid android:color="#FBEBD2" />
    <corners android:radius="16dp" />
    <stroke android:width="1dp" android:color="#DDA43F" />
</shape>
X

for ic in lock unlock clima trunk; do
  sed -i 's/android:fillColor="#FFFFFF"/android:fillColor="#14507E"/' "$D/qw_ic_$ic.xml"
done
echo "Drawables en claro; iconos a navy"

python3 - << 'PYEOF'
import sys, re
NL = chr(10)

# ---------- layout ----------
p = 'android/app/src/main/res/layout/quick_widget.xml'
s = open(p, encoding='utf-8').read()

cambios = [
    ('android:textColor="#F2F7FB"', 'android:textColor="#0D3B66"'),
    ('android:textColor="#8FA8BC"', 'android:textColor="#5B87AC"'),
    ('android:textColor="#D2E0EC"', 'android:textColor="#144E7A"'),
    ('android:textColor="#E8F1F8"', 'android:textColor="#0D3B66"'),
    ('android:textColor="#FFD9A0"', 'android:textColor="#8A5A12"'),
]
for viejo, nuevo in cambios:
    s = s.replace(viejo, nuevo)

# tercera linea de info + linea de aviso, antes del espaciador flexible
ancla = '''    <LinearLayout
        android:layout_width="match_parent"
        android:layout_height="0dp"
        android:layout_weight="1"
        android:orientation="vertical" />'''
if s.count(ancla) != 1:
    print("ABORTA: espaciador no encontrado"); sys.exit(1)
s = s.replace(ancla, '''    <TextView
        android:id="@+id/qw_info3"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="2dp"
        android:maxLines="1"
        android:ellipsize="end"
        android:textColor="#5B87AC"
        android:textSize="12sp"
        android:visibility="gone"
        android:text="" />

    <TextView
        android:id="@+id/qw_alert"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:layout_marginTop="4dp"
        android:maxLines="1"
        android:ellipsize="end"
        android:textColor="#B3341F"
        android:textStyle="bold"
        android:textSize="12sp"
        android:visibility="gone"
        android:text="" />

''' + ancla)
open(p, 'w', encoding='utf-8').write(s)
print("layout OK")

# ---------- kotlin ----------
p = 'android/app/src/main/kotlin/com/txurtxil/lpb10/QuickWidgetProvider.kt'
s = open(p, encoding='utf-8').read()

def rep(old, new, tag):
    global s
    if s.count(old) != 1:
        print("ABORTA %s: %d ocurrencias" % (tag, s.count(old))); sys.exit(1)
    s = s.replace(old, new)

rep('''        v.setTextViewText(R.id.qw_fresh, antiguedad(ts, updated))
        v.setTextColor(R.id.qw_fresh, if (ts != null &&
                System.currentTimeMillis() - ts > 30 * 60 * 1000L)
            Color.parseColor("#E9A23B") else Color.parseColor("#8FA8BC"))''',
'''        v.setTextViewText(R.id.qw_fresh, antiguedad(ts, updated))
        v.setTextColor(R.id.qw_fresh, if (ts != null &&
                System.currentTimeMillis() - ts > 30 * 60 * 1000L)
            Color.parseColor("#B3341F") else Color.parseColor("#5B87AC"))''', 'color-fresh')

rep('''        v.setTextViewText(R.id.qw_info2, partes.joinToString("  ·  "))''',
'''        v.setTextViewText(R.id.qw_info2, partes.joinToString("  ·  "))

        // Tercera linea: si esta cargando manda el tiempo restante; si no,
        // consumo medio y kilometros del ciclo, que es lo que la app sabe y
        // el widget oficial no da.
        val restante = p.getString("chargeRemainTime", null)?.toIntOrNull()
        val avg7 = p.getString("avg7_kwh100", null)
        val ciclo = p.getString("cycleKm", null)
        val l3 = when {
            charging == "1" && restante != null && restante > 0 ->
                "Completa en " + (if (restante >= 60) (restante / 60).toString() + " h " +
                    (restante % 60).toString() + " min" else restante.toString() + " min")
            else -> {
                val t = ArrayList<String>()
                if (!avg7.isNullOrEmpty()) t.add("media 7d " + avg7 + " kWh/100")
                if (!ciclo.isNullOrEmpty() && ciclo != "pocos datos")
                    t.add(ciclo + " km desde la carga")
                t.joinToString("  ·  ")
            }
        }
        if (l3.isNotEmpty()) {
            v.setTextViewText(R.id.qw_info3, l3)
            v.setViewVisibility(R.id.qw_info3, View.VISIBLE)
        } else {
            v.setViewVisibility(R.id.qw_info3, View.GONE)
        }

        // Aviso solo cuando hay algo que avisar. Un widget que siempre dice
        // "todo bien" deja de mirarse.
        val avisos = ArrayList<String>()
        val ruedas = (p.getString("tireAlerts", "") ?: "").split("|").filter { it.isNotEmpty() }
        if (ruedas.isNotEmpty()) avisos.add("Presion: " + ruedas.joinToString(", "))
        if (locked == "0") avisos.add("El coche esta abierto")
        if (avisos.isEmpty()) {
            v.setViewVisibility(R.id.qw_alert, View.GONE)
        } else {
            v.setTextViewText(R.id.qw_alert, "\\u26A0  " + avisos.joinToString("  ·  "))
            v.setViewVisibility(R.id.qw_alert, View.VISIBLE)
        }''', 'linea3')

rep('''        p.color = Color.parseColor("#1F3446")
        c.drawRoundRect(RectF(0f, 18f, w.toFloat(), h - 6f), 18f, 18f, p)''',
'''        p.color = Color.parseColor("#A9CCE8")
        c.drawRoundRect(RectF(0f, 18f, w.toFloat(), h - 6f), 18f, 18f, p)''', 'pista')

rep('''        val f = pct.coerceIn(0f, 100f) / 100f
        val color = when {
            f <= 0.15f -> Color.parseColor("#E63946")
            f <= 0.35f -> Color.parseColor("#E9A23B")
            else -> Color.parseColor("#2A9D8F")
        }''',
'''        val f = pct.coerceIn(0f, 100f) / 100f
        val color = when {
            f <= 0.15f -> Color.parseColor("#D3455B")
            f <= 0.35f -> Color.parseColor("#E0913B")
            else -> Color.parseColor("#1E9E88")
        }''', 'colores-barra')

rep('''            p.color = Color.parseColor("#0B1A18")
            c.drawText(txt, 22f, h - 24f, p)
        } else {
            p.color = Color.WHITE
            c.drawText(txt, w * f + 22f, h - 24f, p)
        }''',
'''            p.color = Color.WHITE
            c.drawText(txt, 22f, h - 24f, p)
        } else {
            p.color = Color.parseColor("#0D3B66")
            c.drawText(txt, w * f + 22f, h - 24f, p)
        }''', 'texto-barra')

open(p, 'w', encoding='utf-8').write(s)
d = (s.count('('), s.count(')'), s.count('{'), s.count('}'))
print("  kotlin parentesis %d/%d  llaves %d/%d" % d)
if d[0] != d[1] or d[2] != d[3]:
    print("ABORTA: descuadre"); sys.exit(1)
print("kotlin OK")
PYEOF

echo "--- verificaciones ---"
echo -n "iconos navy: "; grep -l '14507E' "$D"/qw_ic_*.xml | wc -l
echo -n "qw_info3: "; grep -c 'qw_info3' "$K/QuickWidgetProvider.kt"
echo -n "qw_alert: "; grep -c 'qw_alert' "$K/QuickWidgetProvider.kt"
echo
echo "--- compilando ---"
flutter build apk --release 2>&1 | tail -5
