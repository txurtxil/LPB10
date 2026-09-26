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
import androidx.car.app.model.CarIcon
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import androidx.core.graphics.drawable.IconCompat
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
    val info: String,
    val kw: Double?,
    val plazas: Int?
)

/**
 * Raiz de la app en Android Auto (categoria POI). Lista los cargadores
 * cercanos segun OpenStreetMap/Overpass. Es la pantalla raiz, no va
 * empujada desde ningun hub: por eso la cabecera lleva APP_ICON (BACK
 * aqui cerraria la app) y la accion de recarga va en la franja inferior.
 *
 * Politica Google: solo puntos de interes y navegacion delegada. NADA de
 * datos del vehiculo en Auto (eso es exclusivo del fabricante).
 */
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
                // Diagnostico (v3.60.192): la pantalla raiz no logueaba nada,
                // asi que el carlog no distinguia "sin posicion" de "sin
                // cargadores" de "Overpass caido". Ahora cada estado deja rastro.
                CarLog.log(carContext, "SERVICE", "load posicion lat=" + lat + " lon=" + lon)
                if (lat == null || lon == null) {
                    errorMsg = "Sin posicion. Abre LMB10 en el movil una vez."
                } else {
                    chargers = fetch(lat, lon)
                    if (chargers.isEmpty()) errorMsg = "Sin cargadores OSM en 5 km."
                }
                CarLog.log(carContext, "SERVICE", "load resultado errorMsg=" + errorMsg + " cargadores=" + chargers.size)
            } catch (e: Exception) {
                CarLog.log(carContext, "SERVICE", "load excepcion " + e.javaClass.simpleName + ": " + e.message)
                errorMsg = "No se pudo consultar Overpass."
            }
            loading = false
            Handler(Looper.getMainLooper()).post {
                try { invalidate() } catch (t: Throwable) {
                    CarLog.log(carContext, "SERVICE", "invalidate tras destruir: " + t.javaClass.simpleName)
                }
            }
        }.start()
    }

    private fun refresh() {
        loading = true
        errorMsg = null
        chargers = emptyList()
        invalidate()
        load()
    }

    private val overpassMirrors = listOf(
        "https://overpass-api.de/api/interpreter",
        "https://overpass.kumi.systems/api/interpreter",
        "https://overpass.private.coffee/api/interpreter"
    )

    private fun parseKw(tags: JSONObject): Double? {
        // OSM: maxpower suele ser "50" o "50 kW". Nos quedamos el numero.
        val raw = tags.optString("maxpower")
        if (raw.isEmpty()) return null
        return Regex("[0-9]+([.,][0-9]+)?").find(raw)
            ?.value?.replace(',', '.')?.toDoubleOrNull()
    }

    private fun fetch(lat: Double, lon: Double): List<CarCharger> {
        val query = "[out:json][timeout:20];node[\"amenity\"=\"charging_station\"](around:5000,$lat,$lon);out body 40;"
        var body: String? = null
        var lastErr: Exception? = null
        // Reintenta en varios espejos: Overpass principal falla a menudo.
        for (mirror in overpassMirrors) {
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
                CarLog.log(carContext, "SERVICE", "overpass fallo " + mirror + ": " + e.javaClass.simpleName)
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
            val kw = tags?.let { parseKw(it) }
            val plazas = tags?.optString("capacity")?.toIntOrNull()
            out.add(CarCharger(name, la, lo, res[0], info, kw, plazas))
        }
        out.sortBy { it.distM }
        // El host trunca las listas a 6 items en marcha: no mandar mas.
        return out.take(6)
    }

    private fun chargerIcon(): CarIcon =
        CarIcon.Builder(IconCompat.createWithResource(carContext, R.drawable.ic_car_charger)).build()

    private fun refreshAction(): Action =
        Action.Builder()
            .setTitle("Actualizar")
            .setIcon(CarIcon.Builder(
                IconCompat.createWithResource(carContext, android.R.drawable.ic_popup_sync)).build())
            .setOnClickListener { refresh() }
            .build()

    private fun subtitle(c: CarCharger): String {
        val partes = ArrayList<String>()
        partes.add(String.format("%.1f km", c.distM / 1000f))
        if (c.kw != null) partes.add(String.format("%.0f kW", c.kw))
        if (c.info.isNotEmpty()) partes.add(c.info)
        if (c.plazas != null) partes.add(c.plazas.toString() + " plazas")
        return partes.joinToString(" · ")
    }

    override fun onGetTemplate(): Template {
        // Diagnostico (v3.60.193): breadcrumb de cada plantilla que se sirve.
        CarLog.log(carContext, "SERVICE", "getTemplate loading=" + loading +
            " errorMsg=" + errorMsg + " cargadores=" + chargers.size +
            " apiLevel=" + carContext.carAppApiLevel)
        try {
            return construirTemplate()
        } catch (t: Throwable) {
            // Antes, una excepcion aqui (p. ej. setNoItemsMessage en un host
            // con carApiLevel < 4) mataba la sesion y el host mostraba el
            // generico "error no esperado". Ahora queda escrito y se sirve
            // una plantilla de carga siempre valida como red de seguridad.
            CarLog.log(carContext, "SERVICE", "getTemplate EXCEPCION " +
                t.javaClass.simpleName + ": " + t.message)
            t.stackTrace.take(12).forEach {
                CarLog.log(carContext, "SERVICE", "  en " + it.toString())
            }
            return ListTemplate.Builder()
                .setLoading(true)
                .setTitle("Cargadores cerca")
                .setHeaderAction(Action.APP_ICON)
                .build()
        }
    }

    private fun construirTemplate(): Template {
        if (loading) {
            return ListTemplate.Builder()
                .setLoading(true)
                .setTitle("Cargadores cerca")
                .setHeaderAction(Action.APP_ICON)
                .build()
        }

        val list = ItemList.Builder()
        val msg = errorMsg
        if (msg != null) {
            // setNoItemsMessage exige carApiLevel >= 4 (androidx.car.app
            // 1.3). La unidad real del B10 negocia un nivel inferior y el
            // build() lanzaba IllegalArgumentException -> "error no
            // esperado". En hosts antiguos se muestra el mensaje como fila.
            if (carContext.carAppApiLevel >= 4) {
                list.setNoItemsMessage(msg)
            } else {
                list.addItem(Row.Builder().setTitle(msg).build())
            }
        } else {
            for (c in chargers) {
                list.addItem(
                    Row.Builder()
                        .setTitle(c.name)
                        .addText(subtitle(c))
                        .setImage(chargerIcon())
                        .setOnClickListener { screenManager.push(ChargerDetailScreen(carContext, c)) }
                        .build()
                )
            }
        }

        return ListTemplate.Builder()
            .setSingleList(list.build())
            .setTitle("Cargadores cerca")
            .setHeaderAction(Action.APP_ICON)
            .addAction(refreshAction())
            .build()
    }
}
