#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
K=android/app/src/main/kotlin/com/txurtxil/lpb10
cp lib/main.dart backups_widget/main.dart.bak_$TS
cp $K/ChargersScreen.kt backups_widget/ChargersScreen.kt.bak_$TS
echo "[i] Backups en *.bak_$TS"

rm -rf /tmp/pruebatest; mkdir -p /tmp/pruebatest
cp lib/main.dart /tmp/pruebatest/main.dart

# ===== [1] Dart: TripPoint.ts ya esta en milisegundos =====
python3 - <<'PYEOF'
import io, sys
d = "/tmp/pruebatest/main.dart"
s = io.open(d, encoding='utf-8').read()

old1 = "        final ms = p.ts * 1000;"
if s.count(old1) != 1:
    sys.exit("ABORT: ancla ms x%d" % s.count(old1))
new1 = '''        // TripPoint.ts YA viene en milisegundos. Multiplicarlo por 1000
        // daba fechas del año 58525 y el filtro de futuro descartaba todos
        // los puntos: por eso no salia ningun dia. Se autodetecta la unidad
        // por si quedan puntos antiguos guardados en segundos.
        final ms = p.ts > 100000000000 ? p.ts : p.ts * 1000;'''
s = s.replace(old1, new1, 1)

old2 = "        final ultima = DateTime.fromMillisecondsSinceEpoch(tp.last.ts * 1000);"
if s.count(old2) != 1:
    sys.exit("ABORT: ancla diag x%d" % s.count(old2))
new2 = '''        final ultimoMs =
            tp.last.ts > 100000000000 ? tp.last.ts : tp.last.ts * 1000;
        final ultima = DateTime.fromMillisecondsSinceEpoch(ultimoMs);'''
s = s.replace(old2, new2, 1)

io.open(d, 'w', encoding='utf-8').write(s)
print("[ok] Dart: unidad de timestamp corregida")
for op,cl,n in [('(',')','par'),('{','}','lla')]:
    print("  diff %s = %d" % (n, s.count(op)-s.count(cl)))
PYEOF

python3 -c "
import io
o=io.open('lib/main.dart',encoding='utf-8').read()
n=io.open('/tmp/pruebatest/main.dart',encoding='utf-8').read()
for op,cl in [('(',')'),('{','}')]:
    assert (o.count(op)-o.count(cl))==(n.count(op)-n.count(cl)), 'DESCUADRE '+op
print('[dry] balance preservado')
"
cp /tmp/pruebatest/main.dart lib/main.dart

# ===== [2] Cargadores: esquema google.navigation (especifico de Maps) =====
python3 - <<'PYEOF'
import io, sys
p = "android/app/src/main/kotlin/com/txurtxil/lpb10/ChargersScreen.kt"
s = io.open(p, encoding='utf-8').read()
old = '"geo:" + c.lat + "," + c.lon + "?q=" + c.lat + "," + c.lon + "(" + Uri.encode(c.name) + ")"'
if s.count(old) != 1:
    sys.exit("ABORT: ancla uri x%d" % s.count(old))
new = '"google.navigation:q=" + c.lat + "," + c.lon'
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8').write(s)
print("[ok] ChargersScreen: esquema google.navigation")
PYEOF

echo "[i] Verificacion:"
echo -n "  autodeteccion ms (2): "; grep -c "100000000000" lib/main.dart
echo -n "  google.navigation (1): "; grep -c "google.navigation" $K/ChargersScreen.kt
echo -n "  bug \$ Dart (0): "; grep -c '\\\$' lib/main.dart || true
