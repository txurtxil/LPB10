package com.txurtxil.lpb10

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.Pane
import androidx.car.app.model.PaneTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import es.antonborri.home_widget.HomeWidgetPlugin

class BatteryScreen(carContext: CarContext) : Screen(carContext) {
    override fun onGetTemplate(): Template {
        val p = HomeWidgetPlugin.getData(carContext)
        val soc = p.getString("soc", null) ?: "--"
        val range = p.getString("range", null) ?: "--"
        val realRange = p.getString("realRange", null)
        val volt = p.getString("volt", null)
        val amp = p.getString("amp", null)
        val kw = p.getString("kw", null)?.toFloatOrNull()
        val temp = p.getString("interiorTemp", null)
        val batTemp = p.getString("batteryTemp", null)
        val chargeMin = p.getString("chargeRemainTime", null)?.toIntOrNull()

        val pane = Pane.Builder()

        pane.addRow(
            Row.Builder()
                .setTitle("Carga")
                .addText(soc + " %" +
                    (if (realRange != null) "   ·   " + range + " km / real ~" + realRange + " km"
                     else "   ·   " + range + " km"))
                .build()
        )

        if (kw != null) {
            val etiqueta = when {
                kw < -0.1f -> "Regenerando"
                kw <= 10f -> "Consumo eficiente"
                kw <= 30f -> "Consumo medio"
                else -> "Consumo alto"
            }
            pane.addRow(
                Row.Builder()
                    .setTitle("Potencia")
                    .addText(String.format("%.2f kW  ·  %s", kw, etiqueta))
                    .build()
            )
        }

        if (!volt.isNullOrEmpty() && !amp.isNullOrEmpty()) {
            pane.addRow(
                Row.Builder()
                    .setTitle("Electrico")
                    .addText(volt + " V  ·  " + amp + " A")
                    .build()
            )
        }

        if (!temp.isNullOrEmpty()) {
            pane.addRow(
                Row.Builder()
                    .setTitle("Temp. interior")
                    .addText(temp + " °C")
                    .build()
            )
        }

        // Se muestra siempre: si el coche no reporta la señal (TCU dormido)
        // se indica, en vez de hacer desaparecer la fila sin explicacion.
        pane.addRow(
            Row.Builder()
                .setTitle("Temp. bateria")
                .addText(if (!batTemp.isNullOrEmpty()) batTemp + " °C" else "-- (no reportada)")
                .build()
        )
        if (chargeMin != null && chargeMin > 0) {
            val h = chargeMin / 60
            val m = chargeMin % 60
            val txt = if (h > 0) h.toString() + " h " + m + " min" else m.toString() + " min"
            pane.addRow(
                Row.Builder()
                    .setTitle("Carga restante")
                    .addText(txt)
                    .build()
            )
        }
        return PaneTemplate.Builder(pane.build())
            .setTitle("Bateria")
            .setHeaderAction(Action.BACK)
            .build()
    }
}
