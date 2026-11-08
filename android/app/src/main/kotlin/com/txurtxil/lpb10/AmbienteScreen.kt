package com.txurtxil.lpb10

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.LocationListener
import android.location.LocationManager
import android.os.Handler
import android.os.Looper
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.CarIcon
import androidx.car.app.model.Pane
import androidx.car.app.model.PaneTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import androidx.core.graphics.drawable.IconCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONObject
import java.net.URL
import kotlin.concurrent.thread

// Ambiente (beta.7): caja tipo Lamborghini pero honesta — barometro REAL
// (sensor del movil), clima local (open-meteo, gratis, cache 20 min) y
// temperaturas del coche (nube). Bitmap sencillo centrado (el host recorta
// bordes: nada cerca de los limites) + filas de texto con los valores.
class AmbienteScreen(carContext: CarContext) : Screen(carContext) {

    private val handler = Handler(Looper.getMainLooper())
    private var pressureHpa: Float? = null
    private var lastLat = 0.0
    private var lastLon = 0.0
    private var outTempTxt = "--"
    private var weatherTxt = "clima local: --"
    private var windTxt = "-- km/h"
    private var lastWeatherMs = 0L

    private val pressureListener = object : SensorEventListener {
        override fun onSensorChanged(e: SensorEvent) {
            if (e.sensor.type == Sensor.TYPE_PRESSURE) {
                pressureHpa = e.values[0]
                invalidate()
            }
        }
        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
    }

    private val locListener = LocationListener { loc ->
        lastLat = loc.latitude
        lastLon = loc.longitude
        maybeFetchWeather()
        invalidate()
    }

    private val refresher = object : Runnable {
        override fun run() {
            maybeFetchWeather()
            invalidate()
            handler.postDelayed(this, 5000)
        }
    }

    init {
        val sm = carContext.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        sm.getDefaultSensor(Sensor.TYPE_PRESSURE)?.let {
            sm.registerListener(pressureListener, it, SensorManager.SENSOR_DELAY_NORMAL)
        }
        val lm = carContext.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        if (carContext.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED) {
            try {
                if (android.os.Build.VERSION.SDK_INT >= 31) {
                    lm.requestLocationUpdates(LocationManager.FUSED_PROVIDER, 1000L, 0f, locListener)
                } else {
                    lm.requestLocationUpdates(LocationManager.GPS_PROVIDER, 1000L, 0f, locListener)
                }
            } catch (_: SecurityException) { }
        }
        lifecycle.addObserver(LifecycleEventObserver { _, ev ->
            if (ev == Lifecycle.Event.ON_DESTROY) {
                sm.unregisterListener(pressureListener)
                lm.removeUpdates(locListener)
                handler.removeCallbacks(refresher)
            }
        })
        handler.post(refresher)
    }

    private fun d(name: String): String =
        HomeWidgetPlugin.getData(carContext).getString(name, "") ?: ""

    private fun maybeFetchWeather() {
        val now = System.currentTimeMillis()
        if (now - lastWeatherMs < 20 * 60 * 1000 || lastLat == 0.0) return
        lastWeatherMs = now
        thread {
            try {
                val u = ("https://api.open-meteo.com/v1/forecast?latitude=%.4f&longitude=%.4f" +
                    "&current=temperature_2m,weathercode,windspeed_10m&wind_speed_unit=kmh&timezone=auto")
                    .format(lastLat, lastLon)
                val conn = URL(u).openConnection()
                conn.connectTimeout = 8000
                conn.readTimeout = 8000
                val json = JSONObject(conn.getInputStream().bufferedReader().readText())
                val cur = json.getJSONObject("current")
                outTempTxt = "%.1f C".format(cur.getDouble("temperature_2m"))
                windTxt = "%.0f km/h".format(cur.getDouble("windspeed_10m"))
                weatherTxt = weatherCodeText(cur.getInt("weathercode"))
                handler.post { invalidate() }
            } catch (_: Exception) { }
        }
    }

    private fun weatherCodeText(code: Int): String = when (code) {
        0 -> "Despejado"
        1 -> "Mayormente despejado"
        2 -> "Algo nuboso"
        3 -> "Nublado"
        45, 48 -> "Niebla"
        51, 53, 55 -> "Llovizna"
        56, 57 -> "Llovizna helada"
        61 -> "Lluvia ligera"
        63 -> "Lluvia"
        65 -> "Lluvia fuerte"
        66, 67 -> "Lluvia helada"
        71, 73, 75, 77 -> "Nieve"
        80, 81, 82 -> "Chubascos"
        85, 86 -> "Nevada"
        95 -> "Tormenta"
        96, 99 -> "Tormenta con granizo"
        else -> "Clima (" + code + ")"
    }

    override fun onGetTemplate(): Template {
        val bmp = Bitmap.createBitmap(960, 620, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        c.drawColor(Color.rgb(13, 15, 19))
        fun pt(color: Int, size: Float, bold: Boolean = false) = Paint().apply {
            this.color = color; textSize = size; isAntiAlias = true
            textAlign = Paint.Align.CENTER
            if (bold) typeface = android.graphics.Typeface.DEFAULT_BOLD
        }
        val pres = if (pressureHpa == null) "-- hPa" else "%.0f hPa".format(pressureHpa)
        val interior = d("interiorTemp")
        val btemp = d("batteryTemp")
        // contenido CENTRADO y lejos de los bordes (el host recorta la caja)
        c.drawText("AMBIENTE", 480f, 130f, pt(Color.rgb(150, 155, 165), 32f))
        c.drawText(outTempTxt, 480f, 280f, pt(Color.WHITE, 110f, bold = true))
        c.drawText(weatherTxt, 480f, 350f, pt(Color.rgb(155, 124, 255), 38f))
        c.drawText("viento $windTxt   barometro $pres", 480f, 430f, pt(Color.rgb(205, 209, 218), 32f))
        val temps = "interior " + (if (interior.isEmpty()) "--" else interior) +
            " C   bateria " + (if (btemp.isEmpty()) "--" else btemp) + " C"
        c.drawText(temps, 480f, 500f, pt(Color.rgb(150, 155, 165), 28f))

        val pane = Pane.Builder()
            .setImage(CarIcon.Builder(IconCompat.createWithBitmap(bmp)).build())
            .addRow(Row.Builder().setTitle("LMB10 3.60.269-beta.7").addText("API " + carContext.carAppApiLevel).build())
            .addRow(Row.Builder().setTitle(pres).addText("Presion barometrica (sensor del movil)").build())
            .addRow(Row.Builder().setTitle("$outTempTxt · $windTxt").addText("Clima local (open-meteo)").build())
            .build()
        return PaneTemplate.Builder(pane)
            .setTitle("LMB10 - Ambiente")
            .setHeaderAction(Action.BACK)
            .build()
    }
}
