package com.txurtxil.lpb10

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.CarColor
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import es.antonborri.home_widget.HomeWidgetPlugin

class TiresScreen(carContext: CarContext) : Screen(carContext) {
    override fun onGetTemplate(): Template {
        val p = HomeWidgetPlugin.getData(carContext)
        val alertsRaw = p.getString("tireAlerts", "") ?: ""
        val alerts = alertsRaw.split("|").filter { it.isNotEmpty() }.toSet()

        val ruedas = listOf("Del. izq.", "Del. der.", "Tras. izq.", "Tras. der.")
        val list = ItemList.Builder()

        for (r in ruedas) {
            val alerta = alerts.contains(r)
            val barra = if (alerta) "████░░░░" else "████████"
            val estado = if (alerta) "REVISAR" else "OK"
            val row = Row.Builder()
                .setTitle(r)
                .addText(barra + "   " + estado)
            list.addItem(row.build())
        }

        val msg = if (alerts.isEmpty())
            "Todas las ruedas correctas"
        else
            "Revisa: " + alerts.joinToString(", ")

        list.addItem(Row.Builder().setTitle("Resumen").addText(msg).build())

        return ListTemplate.Builder()
            .setSingleList(list.build())
            .setTitle("Ruedas")
            .setHeaderAction(Action.BACK)
            .build()
    }
}
