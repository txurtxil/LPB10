package com.txurtxil.lpb10

import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.SearchTemplate
import androidx.car.app.model.Template
import java.net.HttpURLConnection
import java.net.URL
import org.json.JSONArray

/// Busqueda de destinos (v3.60.198): SearchTemplate + Nominatim. Tocar un
/// resultado navega con Maps del coche (CarContext.ACTION_NAVIGATE, valido
/// para la categoria POI). Sin datos del vehiculo: solo destinos, como
/// manda la politica de Android Auto para apps de terceros.
class AutoSearchScreen(carContext: CarContext) : Screen(carContext) {

    private var resultados: List<Triple<String, Double, Double>> = emptyList()
    private var mostrandoResultados = false

    override fun onGetTemplate(): Template {
        if (mostrandoResultados) return construirResultados()
        return SearchTemplate.Builder(object : SearchTemplate.SearchCallback {
            override fun onSearchTextChanged(query: String) {}
            override fun onSearchSubmitted(query: String) {
                buscar(query)
            }
        })
            .setHeaderAction(Action.BACK)
            .setSearchHint("Direccion o lugar")
            .build()
    }

    private fun construirResultados(): Template {
        val list = ItemList.Builder()
        if (resultados.isEmpty()) {
            list.addItem(Row.Builder()
                .setTitle("Sin resultados. Vuelve atras e intentalo de nuevo.")
                .build())
        } else {
            for (r in resultados) {
                list.addItem(Row.Builder()
                    .setTitle(r.first)
                    .setOnClickListener { navegar(r.second, r.third) }
                    .build())
            }
        }
        return ListTemplate.Builder()
            .setSingleList(list.build())
            .setTitle("Resultados")
            .setHeaderAction(Action.BACK)
            .build()
    }

    private fun buscar(q: String) {
        if (q.trim().length < 3) return
        Thread {
            var lista = emptyList<Triple<String, Double, Double>>()
            try {
                val url = URL("https://nominatim.openstreetmap.org/search?q=" +
                    Uri.encode(q) + "&format=jsonv2&limit=5&accept-language=es")
                val conn = url.openConnection() as HttpURLConnection
                conn.setRequestProperty("User-Agent",
                    "LMB10/3.60.198 (app no oficial Leapmotor B10)")
                conn.connectTimeout = 15000
                conn.readTimeout = 15000
                val code = conn.responseCode
                if (code == 200) {
                    val body = conn.inputStream.bufferedReader().use { it.readText() }
                    val arr = JSONArray(body)
                    val out = ArrayList<Triple<String, Double, Double>>()
                    for (i in 0 until arr.length()) {
                        val o = arr.getJSONObject(i)
                        out.add(Triple(o.optString("display_name"),
                            o.optDouble("lat"), o.optDouble("lon")))
                    }
                    lista = out
                } else {
                    CarLog.log(carContext, "NAV", "search HTTP " + code)
                }
            } catch (e: Exception) {
                CarLog.log(carContext, "NAV",
                    "search excepcion " + e.javaClass.simpleName + ": " + e.message)
            }
            resultados = lista
            mostrandoResultados = true
            Handler(Looper.getMainLooper()).post {
                try { invalidate() } catch (_: Throwable) {}
            }
        }.start()
    }

    private fun navegar(lat: Double, lon: Double) {
        try {
            val uri = Uri.parse("geo:" + lat + "," + lon + "?q=" + lat + "," + lon)
            carContext.startCarApp(Intent(CarContext.ACTION_NAVIGATE, uri))
        } catch (t: Throwable) {
            CarLog.log(carContext, "NAV", "navegar EXCEPCION " + t.javaClass.simpleName)
        }
    }
}
