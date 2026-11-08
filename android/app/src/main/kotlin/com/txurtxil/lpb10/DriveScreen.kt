package com.txurtxil.lpb10

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationListener
import android.location.LocationManager
import android.os.Handler
import android.os.Looper
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

// Cuadro de conduccion (issue #18, @MF_Pau): texto GRANDE en filas.
// Lecciones del host del B10: las imagenes (lista y grid) salen diminutas
// y la superficie libre esta denegada => lo unico legible en plantillas es
// el TEXTO. Valor enorme en el titulo, etiqueta pequena en el cuerpo.
// Velocidad por GPS del movil (~1 s); resto de la nube (refresh ~24 s).
class DriveScreen(carContext: CarContext) : Screen(carContext) {

    private val handler = Handler(Looper.getMainLooper())
    private var ticks = 0
    private var phoneSpeedKmh: Float? = null
    private var lastFixMs: Long = 0

    private val refresher = object : Runnable {
        override fun run() {
            ticks++
            if (ticks % 6 == 1) CarBridge.invoke("refresh", null) { }
            invalidate()
            handler.postDelayed(this, 4000)
        }
    }

    private val locListener = LocationListener { loc ->
        if (loc.hasSpeed()) {
            phoneSpeedKmh = loc.speed * 3.6f
            lastFixMs = System.currentTimeMillis()
        }
        invalidate()
    }

    init {
        val lm = carContext.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        if (carContext.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED) {
            try {
                lm.requestLocationUpdates(LocationManager.GPS_PROVIDER, 1000L, 0f, locListener)
            } catch (_: SecurityException) { }
        }
        lifecycle.addObserver(LifecycleEventObserver { _, ev ->
            if (ev == Lifecycle.Event.ON_DESTROY) {
                lm.removeUpdates(locListener)
                handler.removeCallbacks(refresher)
            }
        })
        CarBridge.invoke("refresh", null) { }
        handler.post(refresher)
    }

    private fun d(name: String): String =
        HomeWidgetPlugin.getData(carContext).getString(name, "") ?: ""

    private fun currentSpeed(): Float {
        val gps = phoneSpeedKmh?.takeIf { System.currentTimeMillis() - lastFixMs < 6000 }
        if (gps != null) return gps
        return d("speed").toFloatOrNull() ?: 0f
    }

    override fun onGetTemplate(): Template {
        val speed = currentSpeed()
        val kwS = d("kw")
        val kw = kwS.toFloatOrNull()
        val soc = d("soc")
        val range = d("range")
        val hora = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date())
        val kwh100 = if (speed >= 5f && kw != null) "%.1f".format(kw / speed * 100f) else "--"

        val energiaTitulo = when {
            kwS.isEmpty() -> "-- kW"
            kw != null && kw < 0f -> "%.1f kW (regenerando)".format(kw)
            else -> "$kwS kW"
        }

        val list = ItemList.Builder()
        list.addItem(fila("%.0f km/h".format(speed), "Velocidad"))
        list.addItem(fila(if (soc.isEmpty()) "-- %" else "$soc %", "Bateria"))
        list.addItem(fila(if (range.isEmpty()) "-- km" else "$range km", "Autonomia"))
        list.addItem(fila(energiaTitulo, "Energia"))
        list.addItem(fila(if (kwh100 == "--") "-- kWh/100" else "$kwh100 kWh/100", "Consumo del momento"))
        list.addItem(fila(hora, "Hora"))
        list.addItem(fila("-- m", "Desnivel (proximamente, issue #17)"))
        list.addItem(fila("API " + carContext.carAppApiLevel, "Nivel del cabezal (debug graficos)"))
        return ListTemplate.Builder()
            .setTitle("LMB10 - Conduccion")
            .setHeaderAction(Action.BACK)
            .setSingleList(list.build())
            .build()
    }

    private fun fila(valor: String, etiqueta: String): Row =
        Row.Builder()
            .setTitle(valor)
            .addText(etiqueta)
            .build()
}
