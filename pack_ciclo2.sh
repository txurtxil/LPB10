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

# 1. _buildTextChart: no pintar "Media 7d" si weekAvg es inverosimil
old1 = '''  if (weekAvg != null) {
    final estFull = (kB10BatteryKwh / weekAvg * 100).round();
    sb.writeln('Media 7d ${_d1(weekAvg)}  ~$estFull km');'''
new1 = '''  if (weekAvg != null && weekAvg >= 12.0) {
    final estFull = (kB10BatteryKwh / weekAvg * 100).round();
    sb.writeln('Media 7d ${_d1(weekAvg)}  ~$estFull km');'''
if s.count(old1) != 1:
    sys.exit("ABORT: ancla textchart x%d" % s.count(old1))
s = s.replace(old1, new1, 1)

# 2. _renderChartPng: mismo filtro (linea ~320-323)
old2 = '''  if (weekAvg != null) {
    final estFull = (kB10BatteryKwh / weekAvg * 100).round();
    final ok = weekAvg <= kTargetKwh100;'''
new2 = '''  if (weekAvg != null && weekAvg >= 12.0) {
    final estFull = (kB10BatteryKwh / weekAvg * 100).round();
    final ok = weekAvg <= kTargetKwh100;'''
if s.count(old2) != 1:
    sys.exit("ABORT: ancla renderpng x%d" % s.count(old2))
s = s.replace(old2, new2, 1)

# 3. cycleKm: en vez de dejarlo vacio si es inverosimil, indicar "pocos datos"
old3 = '''      if (rechargeIdx < points.length - 1) {
        final km = points.last.km - points[rechargeIdx].km;
        // Cordura: el ciclo no puede superar la autonomia fisica del coche.
        // Si sale > kB10MaxRangeKm es que no se detecto bien la recarga
        // (histiorial incompleto) o hay un salto de odometro: no mostrar.
        if (km > 0 && km <= kB10MaxRangeKm) cycleKm = km.toString();
      }'''
new3 = '''      if (rechargeIdx < points.length - 1) {
        final km = points.last.km - points[rechargeIdx].km;
        // Cordura: el ciclo no puede superar la autonomia fisica del coche.
        // Si sale > kB10MaxRangeKm es que aun no hay suficiente historial
        // para localizar la ultima recarga real (se ve todo el rango
        // disponible en vez de un ciclo). Se avisa en vez de ocultarlo sin
        // explicar, para que quede claro que es falta de datos, no un fallo.
        if (km > 0) {
          cycleKm = km <= kB10MaxRangeKm ? km.toString() : 'pocos datos';
        }
      }'''
if s.count(old3) != 1:
    sys.exit("ABORT: ancla cycleKm x%d" % s.count(old3))
s = s.replace(old3, new3, 1)

io.open(d, 'w', encoding='utf-8').write(s)
print("[ok] widget_chart.dart: filtro aplicado en textChart, PNG y cycleKm")
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

echo "[i] Verificacion:"
echo -n "  textchart filtrado (1): "; grep -c "weekAvg != null && weekAvg >= 12.0" lib/widget_chart.dart
echo -n "  cycleKm con aviso (1): "; grep -c "'pocos datos'" lib/widget_chart.dart
