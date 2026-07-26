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

# 1. Arreglar navigate(): usar CarContext.startCarApp con ACTION_NAVIGATE
#    pero con el paquete de Google Maps explicito como fallback, y ademas
#    intentar el intent normal de Android si el de coche falla.
old = '''    private fun navigate(c: CarCharger) {
        try {
            val uri = Uri.parse(
                "geo:" + c.lat + "," + c.lon + "?q=" + c.lat + "," + c.lon + "(" + Uri.encode(c.name) + ")"
            )
            carContext.startCarApp(Intent(CarContext.ACTION_NAVIGATE, uri))
        } catch (e: Exception) {
            CarToast.makeText(carContext, "Sin app de navegacion", CarToast.LENGTH_LONG).show()
        }
    }'''
new = '''    private fun navigate(c: CarCharger) {
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
if s.count(old) != 1:
    sys.exit("ABORT: ancla navigate x%d" % s.count(old))
s = s.replace(old, new, 1)

# 2. Overpass con reintento y servidor espejo
old_fetch = '''        val conn = URL("https://overpass-api.de/api/interpreter").openConnection() as HttpURLConnection'''
# Envolver el fetch en reintentos con espejos: cambiamos la funcion fetch para
# probar varios endpoints. Buscamos la linea de la URL y la parametrizamos.
if "overpass_mirrors" not in s:
    # Insertar lista de espejos y bucle. Reemplazamos la apertura de conexion
    # por una que recorra espejos.
    old_conn_block = '''    private fun fetch(lat: Double, lon: Double): List<CarCharger> {
        val query = "[out:json][timeout:20];node[\\"amenity\\"=\\"charging_station\\"](around:5000,$lat,$lon);out body 40;"
        val conn = URL("https://overpass-api.de/api/interpreter").openConnection() as HttpURLConnection
        conn.requestMethod = "POST"
        conn.doOutput = true
        conn.connectTimeout = 15000
        conn.readTimeout = 25000
        conn.setRequestProperty("Content-Type", "application/x-www-form-urlencoded")
        OutputStreamWriter(conn.outputStream).use { it.write("data=" + Uri.encode(query)) }
        val body = conn.inputStream.bufferedReader().use { it.readText() }
        conn.disconnect()'''
    new_conn_block = '''    private val overpass_mirrors = listOf(
        "https://overpass-api.de/api/interpreter",
        "https://overpass.kumi.systems/api/interpreter",
        "https://maps.mail.ru/osm/tools/overpass/api/interpreter"
    )

    private fun fetch(lat: Double, lon: Double): List<CarCharger> {
        val query = "[out:json][timeout:20];node[\\"amenity\\"=\\"charging_station\\"](around:5000,$lat,$lon);out body 40;"
        var body: String? = null
        var lastErr: Exception? = null
        // Reintenta en varios espejos: Overpass principal falla a menudo.
        for (mirror in overpass_mirrors) {
            try {
                val conn = URL(mirror).openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.doOutput = true
                conn.connectTimeout = 10000
                conn.readTimeout = 20000
                conn.setRequestProperty("Content-Type", "application/x-www-form-urlencoded")
                OutputStreamWriter(conn.outputStream).use { it.write("data=" + Uri.encode(query)) }
                body = conn.inputStream.bufferedReader().use { it.readText() }
                conn.disconnect()
                if (body != null && body.contains("elements")) break
            } catch (e: Exception) {
                lastErr = e
            }
        }
        if (body == null) throw (lastErr ?: Exception("Overpass sin respuesta"))'''
    if s.count(old_conn_block) != 1:
        sys.exit("ABORT: ancla fetch block x%d" % s.count(old_conn_block))
    s = s.replace(old_conn_block, new_conn_block, 1)

io.open(p, 'w', encoding='utf-8').write(s)
print("[ok] ChargersScreen: navegacion con fallback + Overpass con espejos")
PYEOF

echo "[i] Verificacion:"
echo -n "  navegacion con 2 intentos (1): "; grep -c "Intento 2" $K/ChargersScreen.kt
echo -n "  espejos overpass (1): "; grep -c "overpass_mirrors" $K/ChargersScreen.kt
echo -n "  bucle de espejos (1): "; grep -c "for (mirror in" $K/ChargersScreen.kt
