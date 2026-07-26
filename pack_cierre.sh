#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
K=android/app/src/main/kotlin/com/txurtxil/lpb10
cp lib/main.dart backups_widget/main.dart.bak_$TS
cp $K/ChargersScreen.kt backups_widget/ChargersScreen.kt.bak_$TS
echo "[i] Backups en *.bak_$TS"

# ===== [2] Quitar el setPackage: volver al intent simple de la 3.58.2 =====
python3 - <<'PYEOF'
import io, sys
p = "android/app/src/main/kotlin/com/txurtxil/lpb10/ChargersScreen.kt"
s = io.open(p, encoding='utf-8').read()
old = '''        // LMB10 es categoria NAVIGATION, asi que el host la trata como "app de
        // navegacion por defecto" y el intent le vuelve a ella misma (se veia
        // en el log: onCreateScreen repetido). Se intenta dirigir el intent
        // explicitamente a Google Maps.
        try {
            val i = Intent(CarContext.ACTION_NAVIGATE, uri)
            i.setPackage("com.google.android.apps.maps")
            CarLog.log(carContext, "NAV", "intento maps " + uri)
            carContext.startCarApp(i)
            return
        } catch (e: Exception) {
            CarLog.log(carContext, "NAV", "maps fallo: " + e.message)
        }
        try {
            CarLog.log(carContext, "NAV", "intento host " + uri)'''
new = '''        // Se vuelve al comportamiento de la v3.58.2, que SI abria el mapa:
        // intent de navegacion simple, sin forzar paquete (forzarlo hacia que
        // el host ignorara el intent en silencio) y con el URI que llevaba ?q=.
        try {
            CarLog.log(carContext, "NAV", "intento " + uri)'''
if s.count(old) != 1:
    sys.exit("ABORT: ancla navigate x%d (revisar con grep -n)" % s.count(old))
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8').write(s)
print("[ok] navigate: intent simple, sin setPackage")
PYEOF

# ===== [3] Diagnostico real de por que no salen los dias =====
rm -rf /tmp/pruebatest; mkdir -p /tmp/pruebatest
cp lib/main.dart /tmp/pruebatest/main.dart
python3 - <<'PYEOF'
import io, sys
d = "/tmp/pruebatest/main.dart"
s = io.open(d, encoding='utf-8').read()
old = "      await HomeWidget.saveWidgetData<String>('cycle_days', dayParts.join(','));"
if s.count(old) != 1:
    sys.exit("ABORT: ancla cycle_days x%d" % s.count(old))
new = '''      // Diagnostico: deja en el log del coche por que salen o no los dias.
      if (tp.isNotEmpty) {
        final ultima = DateTime.fromMillisecondsSinceEpoch(tp.last.ts * 1000);
        await CarLogBridge.log(
            'CONSUMO puntos=${tp.length} ultimoTs=${tp.last.ts} fecha=${ultima.toIso8601String()}');
      }
      await CarLogBridge.log(
          'CONSUMO dias=${byDay.keys.join("|")} parts=${dayParts.join("|")}');
''' + old
s = s.replace(old, new, 1)
io.open(d, 'w', encoding='utf-8').write(s)
print("[ok] Dart: log de diagnostico del consumo por dias")
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

echo "[i] Verificacion:"
echo -n "  setPackage fuera (0): "; grep -c "setPackage" $K/ChargersScreen.kt || true
echo -n "  URI con ?q= (1): "; grep -c 'q=" + c.lat' $K/ChargersScreen.kt
echo -n "  log de consumo (2): "; grep -c "CONSUMO " lib/main.dart
echo -n "  bug \$ Dart (0): "; grep -c '\\\$' lib/main.dart || true
