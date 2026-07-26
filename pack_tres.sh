#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
K=android/app/src/main/kotlin/com/txurtxil/lpb10
cp lib/main.dart backups_widget/main.dart.bak_$TS
cp $K/BatteryScreen.kt backups_widget/BatteryScreen.kt.bak_$TS
cp $K/ChargersScreen.kt backups_widget/ChargersScreen.kt.bak_$TS
echo "[i] Backups en *.bak_$TS"

rm -rf /tmp/pruebatest; mkdir -p /tmp/pruebatest
cp lib/main.dart /tmp/pruebatest/main.dart

# ===== [3] Dart: dias de consumo sin exigir ciclo multi-dia =====
python3 - <<'PYEOF'
import io, sys
d = "/tmp/pruebatest/main.dart"
s = io.open(d, encoding='utf-8').read()

old = '''      final dayParts = <String>[];
      if (byDay.length > 1) {
        for (final entry in byDay.entries) {
          final a = TripPointStore.averageConsumptionPercentPer100km(entry.value);
          final kwh = a == null ? '' : (a / 100.0 * kB10BatteryKwh).toStringAsFixed(1);
          dayParts.add('${entry.key}:$kwh');
        }
      }'''
new = '''      // Antes solo se generaban barras si el ciclo abarcaba mas de un dia.
      // Con carga diaria el ciclo dura 1 dia y NUNCA salian barras. Ahora se
      // publican todos los dias con datos (maximo los 7 ultimos).
      final dayParts = <String>[];
      for (final entry in byDay.entries) {
        final a = TripPointStore.averageConsumptionPercentPer100km(entry.value);
        final kwh = a == null ? '' : (a / 100.0 * kB10BatteryKwh).toStringAsFixed(1);
        dayParts.add('${entry.key}:$kwh');
      }
      if (dayParts.length > 7) {
        dayParts.removeRange(0, dayParts.length - 7);
      }'''
if s.count(old) != 1:
    sys.exit("ABORT: ancla dayParts x%d" % s.count(old))
s = s.replace(old, new, 1)
io.open(d, 'w', encoding='utf-8').write(s)
print("[ok] Dart: dias de consumo sin la restriccion multi-dia")
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

# ===== [1] BatteryScreen: mostrar SIEMPRE la fila de temperatura =====
python3 - <<'PYEOF'
import io, sys
p = "android/app/src/main/kotlin/com/txurtxil/lpb10/BatteryScreen.kt"
s = io.open(p, encoding='utf-8').read()
old = '''        if (!batTemp.isNullOrEmpty()) {
            pane.addRow(
                Row.Builder()
                    .setTitle("Temp. bateria")
                    .addText(batTemp + " \u00b0C")
                    .build()
            )
        }'''
new = '''        // Se muestra siempre: si el coche no reporta la señal (TCU dormido)
        // se indica, en vez de hacer desaparecer la fila sin explicacion.
        pane.addRow(
            Row.Builder()
                .setTitle("Temp. bateria")
                .addText(if (!batTemp.isNullOrEmpty()) batTemp + " \u00b0C" else "-- (no reportada)")
                .build()
        )'''
if s.count(old) != 1:
    sys.exit("ABORT: ancla batTemp x%d" % s.count(old))
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8').write(s)
print("[ok] BatteryScreen: temperatura siempre visible")
PYEOF

# ===== [2] ChargersScreen: forzar Google Maps + log de evidencia =====
python3 - <<'PYEOF'
import io, sys
p = "android/app/src/main/kotlin/com/txurtxil/lpb10/ChargersScreen.kt"
s = io.open(p, encoding='utf-8').read()
old = '''        try {
            val uri = Uri.parse("geo:" + c.lat + "," + c.lon)
            carContext.startCarApp(Intent(CarContext.ACTION_NAVIGATE, uri))
        } catch (e: Exception) {
            CarLog.log(carContext, "NAV", "fallo: " + e.message)
            CarToast.makeText(carContext, "No se pudo abrir la navegacion", CarToast.LENGTH_LONG).show()
        }'''
new = '''        val uri = Uri.parse("geo:" + c.lat + "," + c.lon)
        // LMB10 es categoria NAVIGATION, asi que el host la trata como "app de
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
            CarLog.log(carContext, "NAV", "intento host " + uri)
            carContext.startCarApp(Intent(CarContext.ACTION_NAVIGATE, uri))
        } catch (e: Exception) {
            CarLog.log(carContext, "NAV", "fallo: " + e.message)
            CarToast.makeText(carContext, "No se pudo abrir la navegacion", CarToast.LENGTH_LONG).show()
        }'''
if s.count(old) != 1:
    sys.exit("ABORT: ancla navigate x%d" % s.count(old))
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8').write(s)
print("[ok] ChargersScreen: intento dirigido a Maps + logging")
PYEOF

echo "[i] Verificacion:"
echo -n "  dias sin restriccion (1): "; grep -c "maximo los 7 ultimos" lib/main.dart
echo -n "  byDay.length > 1 fuera (0): "; grep -c "byDay.length > 1" lib/main.dart || true
echo -n "  temp siempre visible (1): "; grep -c "no reportada" $K/BatteryScreen.kt
echo -n "  nav dirigido a maps (1): "; grep -c "apps.maps" $K/ChargersScreen.kt
echo -n "  bug \$ Dart (0): "; grep -c '\\\$' lib/main.dart || true
