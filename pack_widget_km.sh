#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
K=android/app/src/main/kotlin/com/txurtxil/lpb10/BatteryWidgetProvider.kt
cp $K backups_widget/BatteryWidgetProvider.kt.bak_$TS
cp lib/widget_chart.dart backups_widget/widget_chart.dart.bak_$TS
echo "[i] Backups en *.bak_$TS"

# ===== 1. Widget kotlin: separar Quedan / Recorrido con etiquetas =====
python3 - <<'PYEOF'
import io, sys
p = "android/app/src/main/kotlin/com/txurtxil/lpb10/BatteryWidgetProvider.kt"
s = io.open(p, encoding='utf-8').read()

old = '''        val cyclePart = if (!cycleKm.isNullOrEmpty()) "  \u00b7  $cycleKm km ciclo" else ""
        val rangeText = when {
            range != null && !realRange.isNullOrEmpty() -> "$range km \u00b7 real ~$realRange km$cyclePart"
            range != null -> "$range km autonomia$cyclePart"
            else -> "-- km autonomia"
        }
        views.setTextViewText(R.id.widget_range, rangeText)'''

new = '''        // Linea 1: lo que QUEDA (autonomia). Linea 2: lo RECORRIDO (ciclo).
        // Antes se mezclaban autonomia y recorrido en una sola linea, lo que
        // parecia contradictorio (miden cosas distintas).
        val quedanText = when {
            range != null && !realRange.isNullOrEmpty() -> "Quedan: $range km (real ~$realRange)"
            range != null -> "Quedan: $range km"
            else -> "Quedan: -- km"
        }
        val recorridoText = when {
            cycleKm == "pocos datos" -> "Recorrido: -- (pocos datos)"
            !cycleKm.isNullOrEmpty() -> "Recorrido: $cycleKm km desde la carga"
            else -> "Recorrido: -- km"
        }
        views.setTextViewText(R.id.widget_range, quedanText + "\\n" + recorridoText)'''

if s.count(old) != 1:
    sys.exit("ABORT: ancla rangeText x%d" % s.count(old))
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8').write(s)
print("[ok] widget kotlin: Quedan / Recorrido separados")
PYEOF

# ===== 2. Dart: capar autonomia estimada a 430 (fisica del coche) =====
python3 - <<'PYEOF'
import io, sys
d = "lib/widget_chart.dart"
s = io.open(d, encoding='utf-8').read()

# 2a. realRange: capar a 430 en vez de 999
old1 = '''      final r = (socPercent * kB10BatteryKwh / weekAvg).clamp(0.0, 999.0);
      realRange = r.round().toString();'''
new1 = '''      // Cap a la autonomia fisica: con pocos datos el consumo medio sale
      // optimista y daria autonomias imposibles (>430). Se limita a 430.
      final r = (socPercent * kB10BatteryKwh / weekAvg).clamp(0.0, kB10MaxRangeKm);
      realRange = r.round().toString();'''
if s.count(old1) != 1:
    sys.exit("ABORT: ancla realRange clamp x%d" % s.count(old1))
s = s.replace(old1, new1, 1)

# 2b. "Media 7d" en textchart: capar el estFull a 430
old2 = '''  if (weekAvg != null && weekAvg >= 12.0) {
    final estFull = (kB10BatteryKwh / weekAvg * 100).round();
    sb.writeln('Media 7d ${_d1(weekAvg)}  ~$estFull km');'''
new2 = '''  if (weekAvg != null && weekAvg >= 12.0) {
    final estFull =
        (kB10BatteryKwh / weekAvg * 100).round().clamp(0, kB10MaxRangeKm.round());
    sb.writeln('Media 7d ${_d1(weekAvg)}  ~$estFull km');'''
if s.count(old2) != 1:
    sys.exit("ABORT: ancla textchart estFull x%d" % s.count(old2))
s = s.replace(old2, new2, 1)

io.open(d, 'w', encoding='utf-8').write(s)
print("[ok] widget_chart.dart: autonomia capada a 430 (realRange y Media 7d)")

for op,cl,n in [('(',')','par'),('{','}','lla')]:
    print("  diff %s = %d" % (n, s.count(op)-s.count(cl)))
PYEOF

python3 -c "
import io
o=io.open('backups_widget/widget_chart.dart.bak_$TS',encoding='utf-8').read()
n=io.open('lib/widget_chart.dart',encoding='utf-8').read()
for op,cl in [('(',')'),('{','}')]:
    assert (o.count(op)-o.count(cl))==(n.count(op)-n.count(cl)), 'DESCUADRE '+op
print('[dry] balance widget_chart preservado')
"

echo "[i] Verificacion:"
echo -n "  Quedan/Recorrido en widget (1): "; grep -c "Recorrido: " $K
echo -n "  autonomia capada realRange (1): "; grep -c "clamp(0.0, kB10MaxRangeKm)" lib/widget_chart.dart
echo -n "  Media 7d capada (1): "; grep -c "kB10MaxRangeKm.round()" lib/widget_chart.dart
echo -n "  bug \$ dart (0): "; grep -c '\\\$' lib/widget_chart.dart || true
