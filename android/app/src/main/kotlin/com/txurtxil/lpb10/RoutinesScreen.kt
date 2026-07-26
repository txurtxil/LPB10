package com.txurtxil.lpb10

import android.os.Handler
import android.os.Looper
import androidx.car.app.CarContext
import androidx.car.app.CarToast
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.CarIcon
import androidx.car.app.model.GridItem
import androidx.car.app.model.GridTemplate
import androidx.car.app.model.ItemList
import androidx.car.app.model.Template
import androidx.core.graphics.drawable.IconCompat
import es.antonborri.home_widget.HomeWidgetPlugin

class RoutinesScreen(carContext: CarContext) : Screen(carContext) {

    private var busy = false

    private fun icon(res: Int): CarIcon =
        CarIcon.Builder(IconCompat.createWithResource(carContext, res)).build()

    private fun iconFor(name: String): Int {
        val n = name.lowercase()
        return when {
            n.contains("cerr") || n.contains("lock") -> R.drawable.ic_car_lock
            n.contains("clima") || n.contains("verano") || n.contains("invierno") ||
                n.contains("calor") || n.contains("frio") -> R.drawable.ic_car_climate
            else -> R.drawable.ic_car_routine
        }
    }

    private fun toast(m: String) {
        Handler(Looper.getMainLooper()).post {
            CarToast.makeText(carContext, m, CarToast.LENGTH_LONG).show()
        }
    }

    private fun run(id: String, name: String) {
        if (busy) { toast("Espera, hay un comando en curso"); return }
        busy = true
        toast(name + ": enviando...")
        CarBridge.invokeStr("runRoutine", mapOf("id" to id)) { res ->
            busy = false
            val msg = when {
                res.isNullOrEmpty() -> name + ": fallo"
                res.startsWith("0/") -> name + ": no ejecutado"
                else -> name + ": " + res.replace("/", " de ")
            }
            toast(msg)
        }
    }

    override fun onGetTemplate(): Template {
        val p = HomeWidgetPlugin.getData(carContext)
        val raw = p.getString("routines_all", "") ?: ""
        val list = ItemList.Builder()

        val entries = raw.split("\n").filter { it.contains("::") }
        if (entries.isEmpty()) {
            list.addItem(
                GridItem.Builder()
                    .setTitle("Sin rutinas")
                    .setImage(icon(R.drawable.ic_car_routine))
                    .build()
            )
        } else {
            // GridTemplate admite hasta 6 items en movimiento.
            for (e in entries.take(6)) {
                val idx = e.indexOf("::")
                val id = e.substring(0, idx)
                val name = e.substring(idx + 2)
                list.addItem(
                    GridItem.Builder()
                        .setTitle(name)
                        .setImage(icon(iconFor(name)))
                        .setOnClickListener { run(id, name) }
                        .build()
                )
            }
        }

        return GridTemplate.Builder()
            .setSingleList(list.build())
            .setTitle("Rutinas")
            .setHeaderAction(Action.BACK)
            .build()
    }
}
