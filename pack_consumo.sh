#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
K=android/app/src/main/kotlin/com/txurtxil/lpb10
cp lib/main.dart backups_widget/main.dart.bak_$TS
cp $K/ConsumoScreen.kt backups_widget/ConsumoScreen.kt.bak_$TS
echo "[i] Backups en *.bak_$TS"

rm -rf /tmp/pruebatest; mkdir -p /tmp/pruebatest
cp lib/main.dart /tmp/pruebatest/main.dart

# ===== 1. Dart: filtrar timestamps futuros + capar est_range a 430 =====
python3 - <<'PYEOF'
import io, sys
d = "/tmp/pruebatest/main.dart"
s = io.open(d, encoding='utf-8').read()

# 1a. Filtrar puntos con ts futuro antes de agrupar por dia
old_group = '''      // Barras por dia (solo si el ciclo abarca >1 dia)
      final byDay = <String, List<TripPoint>>{};
      for (final p in tp) {
        final dt = DateTime.fromMillisecondsSinceEpoch(p.ts * 1000);
        final key = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
        (byDay[key] ??= []).add(p);
      }'''
new_group = '''      // Barras por dia (solo si el ciclo abarca >1 dia).
      // Se descartan puntos con timestamp futuro (imposibles: datos corruptos
      // que hacian aparecer fechas que aun no han llegado, p.ej. agosto en julio).
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final byDay = <String, List<TripPoint>>{};
      for (final p in tp) {
        final ms = p.ts * 1000;
        if (ms > nowMs) continue; // punto en el futuro: dato invalido
        final dt = DateTime.fromMillisecondsSinceEpoch(ms);
        final key = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
        (byDay[key] ??= []).add(p);
      }'''
if s.count(old_group) != 1:
    sys.exit("ABORT: ancla byDay x%d" % s.count(old_group))
s = s.replace(old_group, new_group, 1)

# 1b. Capar est_range a la fisica del coche (430)
old_est = '''        final estRange = kwh100 > 0 ? (kB10BatteryKwh / kwh100 * 100).round() : 0;'''
new_est = '''        // Cap a la autonomia fisica del coche: con pocos datos el consumo
        // medio sale optimista y daria autonomias imposibles (>430).
        final estRangeRaw = kwh100 > 0 ? (kB10BatteryKwh / kwh100 * 100).round() : 0;
        final estRange = estRangeRaw > kB10MaxRangeKm.round() ? kB10MaxRangeKm.round() : estRangeRaw;'''
if s.count(old_est) != 1:
    sys.exit("ABORT: ancla estRange x%d" % s.count(old_est))
s = s.replace(old_est, new_est, 1)

io.open(d, 'w', encoding='utf-8').write(s)
print("[ok] Dart: filtro ts futuro + cap est_range a 430")
for op,cl,n in [('(',')','par'),('{','}','lla')]:
    print("  diff %s = %d" % (n, s.count(op)-s.count(cl)))
PYEOF

python3 -c "
import io
o=io.open('lib/main.dart',encoding='utf-8').read()
n=io.open('/tmp/pruebatest/main.dart',encoding='utf-8').read()
for op,cl in [('(',')'),('{','}')]:
    assert (o.count(op)-o.count(cl))==(n.count(op)-n.count(cl)), 'DESCUADRE '+op
print('[dry] balance main preservado')
"
cp /tmp/pruebatest/main.dart lib/main.dart

# ===== 2. ConsumoScreen mas limpio: sin "-- insuficiente" repetido =====
python3 - <<'PYEOF'
import io, sys
p = "android/app/src/main/kotlin/com/txurtxil/lpb10/ConsumoScreen.kt"
s = io.open(p, encoding='utf-8').read()

# Solo mostrar dias que TIENEN dato (no llenar de "-- insuficiente").
# Si ninguno tiene dato, mostrar una sola linea informativa.
old = '''        // --- BARRAS POR DIA, solo si el ciclo abarca varios dias ---
        val days = daysRaw.split(",").filter { it.contains(":") }
        if (days.isNotEmpty()) {
            val vals = days.mapNotNull { it.substringAfter(":").toFloatOrNull() }
            val maxV = (vals.maxOrNull() ?: 0f).coerceAtLeast(15.6f)
            val titDays = if (es) "Por dia" else "Per day"
            list.addItem(Row.Builder().setTitle(titDays).addText(if (es) "Consumo diario del ciclo" else "Daily use this cycle").build())
            for (d in days) {
                val label = d.substringBefore(":")
                val kwhStr = d.substringAfter(":")
                val kwh = kwhStr.toFloatOrNull()
                val texto = if (kwh == null)
                    (if (es) "-- (insuficiente)" else "-- (insufficient)")
                else bar(kwh, maxV) + "  " + kwhStr + " kWh/100"
                list.addItem(Row.Builder().setTitle(label).addText(texto).build())
            }
        }'''
new = '''        // --- BARRAS POR DIA: solo dias CON dato real, para no ensuciar ---
        val allDays = daysRaw.split(",").filter { it.contains(":") }
        val daysWithData = allDays.filter { it.substringAfter(":").toFloatOrNull() != null }
        if (daysWithData.isNotEmpty()) {
            val vals = daysWithData.mapNotNull { it.substringAfter(":").toFloatOrNull() }
            val maxV = (vals.maxOrNull() ?: 0f).coerceAtLeast(15.6f)
            val titDays = if (es) "Por dia" else "Per day"
            list.addItem(Row.Builder().setTitle(titDays).addText(if (es) "Consumo diario del ciclo" else "Daily use this cycle").build())
            for (d in daysWithData) {
                val label = d.substringBefore(":")
                val kwhStr = d.substringAfter(":")
                val kwh = kwhStr.toFloatOrNull() ?: continue
                val texto = bar(kwh, maxV) + "  " + kwhStr + " kWh/100"
                list.addItem(Row.Builder().setTitle(label).addText(texto).build())
            }
        }'''
if s.count(old) != 1:
    sys.exit("ABORT: ancla barras dia x%d" % s.count(old))
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8').write(s)
print("[ok] ConsumoScreen: solo dias con dato real (mas limpio)")
PYEOF

echo "[i] Verificacion:"
echo -n "  filtro ts futuro (1): "; grep -c "punto en el futuro" lib/main.dart
echo -n "  cap est_range (1): "; grep -c "estRangeRaw > kB10MaxRangeKm" lib/main.dart
echo -n "  ConsumoScreen limpio (1): "; grep -c "daysWithData" $K/ConsumoScreen.kt
echo -n "  bug \$ Dart (0): "; grep -c '\\\$' lib/main.dart || true
