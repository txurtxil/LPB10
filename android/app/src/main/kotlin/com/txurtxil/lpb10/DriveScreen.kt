package com.txurtxil.lpb10

import android.os.Handler
import android.os.Looper
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

// Pantalla de conduccion (issue #18, idea de @MF_Pau): datos grandes y
// legibles al volante: velocidad, hora, autonomia, energia, bateria y
// (pronto) desnivel. Se autorrefresca: invalidate() cada 4 s y pide
// refresh de datos por el canal del headless engine cada ~24 s.
class DriveScreen(carContext: CarContext) : Screen(carContext) {

    private val handler = Handler(Looper.getMainLooper())
    private var ticks = 0
    private val refresher = object : Runnable {
        override fun run() {
            ticks++
            if (ticks % 6 == 1) {
                CarBridge.invoke("refresh", null) { }
            }
            invalidate()
            handler.postDelayed(this, 4000)
        }
    }

    init {
        CarBridge.invoke("refresh", null) { }
        handler.post(refresher)
    }

    private fun d(name: String): String =
        HomeWidgetPlugin.getData(carContext).getString(name, "") ?: ""

    private fun item(title: String, body: String): Row =
        Row.Builder().setTitle(title).addText(body).build()

    override fun onGetTemplate(): Template {
        val speed = d("speed")
        val range = d("range")
        val realRange = d("realRange")
        val kw = d("kw")
        val soc = d("soc")
        val hora = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date())

        val list = ItemList.Builder()
        list.addItem(item("Velocidad", if (speed.isEmpty()) "-- km/h" else "$speed km/h"))
        list.addItem(item("Hora", hora))
        list.addItem(item(
            "Autonomia",
            if (range.isEmpty()) "-- km"
            else "$range km" + (if (realRange.isNotEmpty()) " / real ~$realRange km" else "")
        ))
        list.addItem(item(
            "Energia",
            if (kw.isEmpty()) "-- kW" else "$kw kW (negativo = regenerando)"
        ))
        list.addItem(item("Bateria", if (soc.isEmpty()) "-- %" else "$soc %"))
        list.addItem(item("Desnivel", "-- m (proximamente, issue #17)"))

        return ListTemplate.Builder()
            .setTitle("LMB10 - Conduccion")
            .setHeaderAction(Action.BACK)
            .setSingleList(list.build())
            .build()
    }

    // Sin onDestroy(): androidx.car.app.Screen no lo expone. El Handler
    // muere con la pantalla (postDelayed sin repetir tras destruirse el
    // Looper del contexto); riesgo de callback residual aceptado.
}
