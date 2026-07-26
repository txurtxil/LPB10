#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
K=android/app/src/main/kotlin/com/txurtxil/lpb10
cp $K/ChargersScreen.kt backups_widget/ChargersScreen.kt.bak_$TS
echo "[i] Backup en *.bak_$TS"

python3 - <<'PYEOF'
import io, sys
p = "android/app/src/main/kotlin/com/txurtxil/lpb10/ChargersScreen.kt"
s = io.open(p, encoding='utf-8').read()

old = '''    private fun navigate(c: CarCharger) {
        // Al ser LMB10 categoria NAVIGATION, startCarApp(ACTION_NAVIGATE) puede
        // entrar en conflicto (el sistema cree que LMB10 debe manejar su propia
        // navegacion). Se lanza la navegacion con el intent de coche pero
        // apuntando explicitamente a la app de mapas del coche.
        val uri = Uri.parse(
            "geo:" + c.lat + "," + c.lon + "?q=" + c.lat + "," + c.lon + "(" + Uri.encode(c.name) + ")"
        )
        // Intento 1: intent de navegacion de Android Auto dirigido a Maps
        try {
            val intent = Intent(CarContext.ACTION_NAVIGATE, uri)
            carContext.startCarApp(intent)
            return
        } catch (_: Exception) {}
        // Intento 2: geo directo (deja que el host elija la app de mapas)
        try {
            carContext.startCarApp(Intent(Intent.ACTION_VIEW, uri))
            return
        } catch (_: Exception) {}
        CarToast.makeText(carContext, "No se pudo abrir la navegacion", CarToast.LENGTH_LONG).show()
    }'''
new = '''    private fun navigate(c: CarCharger) {
        // Formato correcto segun la doc oficial de Android Auto: para lanzar
        // navegacion en el coche hay que usar CarContext.ACTION_NAVIGATE con
        // un URI "geo:lat,lon" simple (NO Intent.ACTION_VIEW, que solo vale en
        // el movil). El formato con "?q=lat,lon(nombre)" no lo resuelve bien el
        // host; el formato geo:lat,lon directo si.
        try {
            val uri = Uri.parse("geo:" + c.lat + "," + c.lon)
            carContext.startCarApp(Intent(CarContext.ACTION_NAVIGATE, uri))
        } catch (e: Exception) {
            CarLog.log(carContext, "NAV", "fallo: " + e.message)
            CarToast.makeText(carContext, "No se pudo abrir la navegacion", CarToast.LENGTH_LONG).show()
        }
    }'''
if s.count(old) != 1:
    sys.exit("ABORT: ancla navigate x%d" % s.count(old))
s = s.replace(old, new, 1)
io.open(p, 'w', encoding='utf-8').write(s)
print("[ok] navigate: formato geo:lat,lon correcto + ACTION_NAVIGATE")
PYEOF

echo -n "  geo:lat,lon simple (1): "; grep -c 'geo:" + c.lat + "," + c.lon)' $K/ChargersScreen.kt
echo -n "  ya no usa ACTION_VIEW (0): "; grep -c "ACTION_VIEW" $K/ChargersScreen.kt || true
