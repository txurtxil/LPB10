package com.txurtxil.lpb10

import android.content.Intent
import android.location.Location
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.car.app.CarContext
import androidx.car.app.CarToast
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

data class CarCharger(
    val name: String,
    val lat: Double,
    val lon: Double,
    val distM: Float,
    val info: String
)

class ChargersScreen(carContext: CarContext) : Screen(carContext) {

    private var loading = true
    private var errorMsg: String? = null
    private var chargers: List<CarCharger> = emptyList()

    init { load() }

    private fun load() {
        Thread {
            try {
                val prefs = HomeWidgetPlugin.getData(carContext)
                val lat = prefs.getString("lat", "")?.toDoubleOrNull()
                val lon = prefs.getString("lon", "")?.toDoubleOrNull()
                if (lat == null || lon == null) {
                    errorMsg = "Sin posicion del coche. Abre LMB10 en el movil."
                } else {
                    chargers = fetch(lat, lon)
                    if (chargers.isEmpty()) errorMsg = "Sin cargadores OSM en 5 km."
                }
            } catch (e: Exception) {
                errorMsg = "No se pudo consultar Overpass."
            }
            loading = false
            Handler(Looper.getMainLooper()).post { invalidate() }
        }.start()
    }

    private val overpass_mirrors = listOf(
        "https://overpass-api.de/api/interpreter",
        "https://overpass.kumi.systems/api/interpreter",
        "https://maps.mail.ru/osm/tools/overpass/api/interpreter"
    )

    private fun fetch(lat: Double, lon: Double): List<CarCharger> {
        val query = "[out:json][timeout:20];node[\"amenity\"=\"charging_station\"](around:5000,$lat,$lon);out body 40;"
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
        if (body == null) throw (lastErr ?: Exception("Overpass sin respuesta"))

        val elements = JSONObject(body).optJSONArray("elements") ?: return emptyList()
        val out = ArrayList<CarCharger>()
        for (i in 0 until elements.length()) {
            val e = elements.optJSONObject(i) ?: continue
            val la = e.optDouble("lat", Double.NaN)
            val lo = e.optDouble("lon", Double.NaN)
            if (la.isNaN() || lo.isNaN()) continue
            val tags = e.optJSONObject("tags")
            val nm = tags?.optString("name") ?: ""
            val op = tags?.optString("operator") ?: ""
            val name = when {
                nm.isNotEmpty() -> nm
                op.isNotEmpty() -> op
                else -> "Cargador"
            }
            val res = FloatArray(1)
            Location.distanceBetween(lat, lon, la, lo, res)
            val info = if (nm.isNotEmpty() && op.isNotEmpty()) op else ""
            out.add(CarCharger(name, la, lo, res[0], info))
        }
        out.sortBy { it.distM }
        return out.take(6)
    }

    private fun navigate(c: CarCharger) {
        // Formato correcto segun la doc oficial de Android Auto: para lanzar
        // navegacion en el coche hay que usar CarContext.ACTION_NAVIGATE con
        // un URI "geo:lat,lon" simple (NO Intent.ACTION_VIEW, que solo vale en
        // el movil). El formato con "?q=lat,lon(nombre)" no lo resuelve bien el
        // host; el formato geo:lat,lon directo si.
        // startCarApp(ACTION_NAVIGATE) SOLO admite dos formatos documentados:
        //   "geo:lat,lon"          -> ir a un punto
        //   "geo:0,0?q=..."        -> buscar
        // El hibrido "geo:lat,lon?q=..." NO esta documentado y varios hosts lo
        // descartan EN SILENCIO (sin excepcion). Por eso no pasaba nada.
        val uri = Uri.parse("geo:0,0?q=" + c.lat + "," + c.lon + "(" + Uri.encode(c.name) + ")")
        // Se vuelve al comportamiento de la v3.58.2, que SI abria el mapa:
        // intent de navegacion simple, sin forzar paquete (forzarlo hacia que
        // el host ignorara el intent en silencio) y con el URI que llevaba ?q=.
        try {
            CarLog.log(carContext, "NAV", "intento " + uri)
            carContext.startCarApp(Intent(CarContext.ACTION_NAVIGATE, uri))
            CarLog.log(carContext, "NAV", "startCarApp devuelto SIN excepcion")
        } catch (e: Exception) {
            CarLog.log(carContext, "NAV", "fallo: " + e.javaClass.simpleName + " " + e.message)
            try {
                val simple = Uri.parse("geo:" + c.lat + "," + c.lon)
                CarLog.log(carContext, "NAV", "fallback " + simple)
                carContext.startCarApp(Intent(CarContext.ACTION_NAVIGATE, simple))
                return
            } catch (e2: Exception) {
                CarLog.log(carContext, "NAV", "fallback fallo: " + e2.message)
            }
            CarToast.makeText(carContext, "No se pudo abrir la navegacion", CarToast.LENGTH_LONG).show()
        }
    }

    override fun onGetTemplate(): Template {
        if (loading) {
            return ListTemplate.Builder()
                .setLoading(true)
                .setTitle("Cargadores")
                .setHeaderAction(Action.BACK)
                .build()
        }

        val list = ItemList.Builder()
        val msg = errorMsg
        if (msg != null) {
            list.setNoItemsMessage(msg)
        } else {
            for (c in chargers) {
                val km = String.format("%.1f km", c.distM / 1000f)
                val sub = if (c.info.isNotEmpty()) "$km · ${c.info}" else km
                list.addItem(
                    Row.Builder()
                        .setTitle(c.name)
                        .addText(sub)
                        .setOnClickListener { navigate(c) }
                        .build()
                )
            }
        }

        return ListTemplate.Builder()
            .setSingleList(list.build())
            .setTitle("Cargadores")
            .setHeaderAction(Action.BACK)
            .build()
    }
}
