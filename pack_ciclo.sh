#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
cp lib/widget_chart.dart backups_widget/widget_chart.dart.bak_$TS
echo "[i] Backup en *.bak_$TS"

rm -rf /tmp/pruebatest; mkdir -p /tmp/pruebatest
cp lib/widget_chart.dart /tmp/pruebatest/widget_chart.dart

python3 - <<'PYEOF'
import io, sys
d = "/tmp/pruebatest/widget_chart.dart"
s = io.open(d, encoding='utf-8').read()

# Ver el bloque exacto del cycleKm
old = '''      if (rechargeIdx < points.length - 1) {
        final km = points.last.km - points[rechargeIdx].km;
        if (km > 0) cycleKm = km.toString();
      }'''
new = '''      if (rechargeIdx < points.length - 1) {
        final km = points.last.km - points[rechargeIdx].km;
        // Cordura: el ciclo no puede superar la autonomia fisica del coche.
        // Si sale > kB10MaxRangeKm es que no se detecto bien la recarga
        // (histiorial incompleto) o hay un salto de odometro: no mostrar.
        if (km > 0 && km <= kB10MaxRangeKm) cycleKm = km.toString();
      }'''
if s.count(old) != 1:
    sys.exit("ABORT: ancla cycleKm x%d" % s.count(old))
s = s.replace(old, new, 1)

# Red de seguridad para la autonomia irreal: si weekAvg da un consumo
# fisicamente inverosimil (<12 kWh/100), no publicar realRange fantasia.
old2 = '''    if (weekAvg != null && socPercent != null) {
      final r = (socPercent * kB10BatteryKwh / weekAvg).clamp(0.0, 999.0);
      realRange = r.round().toString();
    }'''
new2 = '''    if (weekAvg != null && socPercent != null && weekAvg >= 12.0) {
      // weekAvg < 12 kWh/100 es inverosimil en este coche (objetivo 15.6):
      // significa datos insuficientes. No se publica una autonomia fantasia.
      final r = (socPercent * kB10BatteryKwh / weekAvg).clamp(0.0, 999.0);
      realRange = r.round().toString();
    }'''
if s.count(old2) != 1:
    sys.exit("ABORT: ancla realRange x%d" % s.count(old2))
s = s.replace(old2, new2, 1)

io.open(d, 'w', encoding='utf-8').write(s)
print("[ok] widget_chart.dart: cordura en km ciclo + autonomia realista")
for op,cl,n in [('(',')','par'),('{','}','lla')]:
    print("  diff %s = %d" % (n, s.count(op)-s.count(cl)))
PYEOF

python3 -c "
import io
o=io.open('lib/widget_chart.dart',encoding='utf-8').read()
n=io.open('/tmp/pruebatest/widget_chart.dart',encoding='utf-8').read()
for op,cl in [('(',')'),('{','}')]:
    assert (o.count(op)-o.count(cl))==(n.count(op)-n.count(cl)), 'DESCUADRE '+op
print('[dry] balance preservado')
"

echo "[i] Dry-run OK. Aplicando..."
cp /tmp/pruebatest/widget_chart.dart lib/widget_chart.dart
echo -n "  cordura ciclo (1): "; grep -c "km <= kB10MaxRangeKm" lib/widget_chart.dart
echo -n "  autonomia realista (1): "; grep -c "weekAvg >= 12.0" lib/widget_chart.dart
