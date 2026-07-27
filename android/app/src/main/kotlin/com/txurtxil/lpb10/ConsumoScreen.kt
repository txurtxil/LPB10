package com.txurtxil.lpb10

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import es.antonborri.home_widget.HomeWidgetPlugin

class ConsumoScreen(carContext: CarContext) : Screen(carContext) {

    private fun bar(value: Float, max: Float): String {
        if (max <= 0f) return ""
        val n = (value / max * 10f).toInt().coerceIn(0, 10)
        return "█".repeat(n) + "░".repeat(10 - n)
    }

    override fun onGetTemplate(): Template {
        val p = HomeWidgetPlugin.getData(carContext)
        val es = (p.getString("lang", "es") ?: "es") == "es"
        val avg = p.getString("cycle_kwh100", "") ?: ""
        val estRange = p.getString("cycle_est_range", "") ?: ""
        val cycleKm = p.getString("cycle_km", "") ?: ""
        val daysRaw = p.getString("cycle_days", "") ?: ""

        val list = ItemList.Builder()

        // --- RESUMEN DEL CICLO, ARRIBA ---
        val titSummary = if (es) "Ciclo actual" else "Current cycle"
        val summaryText = if (avg.isEmpty() || estRange.isEmpty()) {
            if (es) "Media: -- (datos insuficientes)" else "Average: -- (insufficient data)"
        } else {
            val est = estRange.toIntOrNull() ?: 0
            val diff = est - 430
            val rel = if (es) {
                if (diff >= 0) "+$diff km sobre objetivo" else "$diff km bajo objetivo"
            } else {
                if (diff >= 0) "+$diff km over target" else "$diff km under target"
            }
            val kmPart = if (cycleKm.isNotEmpty()) {
                if (es) "$cycleKm km en este ciclo\n" else "$cycleKm km this cycle\n"
            } else ""
            if (es)
                kmPart + "$avg kWh/100 · ~$estRange km reales\nObjetivo 430 km (15,6): $rel"
            else
                kmPart + "$avg kWh/100 · ~$estRange km real\nTarget 430 km (15.6): $rel"
        }
        list.addItem(Row.Builder().setTitle(titSummary).addText(summaryText).build())

        // Media de 7 dias: no depende del ciclo, asi que sigue habiendo cifra
        // aunque acabes de enchufar y el ciclo no tenga datos suficientes.
        val avg7 = p.getString("avg7_kwh100", "") ?: ""
        if (avg7.isNotEmpty()) {
            list.addItem(
                Row.Builder()
                    .setTitle(if (es) "Ultimos 7 dias" else "Last 7 days")
                    .addText(avg7 + " kWh/100")
                    .build()
            )
        }

        // --- BARRAS POR DIA: solo dias CON dato real, para no ensuciar ---
        val allDays = daysRaw.split(",").filter { it.contains(":") }
        val daysWithData = allDays.filter { it.substringAfter(":").toFloatOrNull() != null }
        if (daysWithData.isEmpty()) {
            list.addItem(
                Row.Builder()
                    .setTitle(if (es) "Por dia" else "Per day")
                    .addText(if (es)
                        "Aun no hay datos diarios. Se registraran con el uso."
                        else "No daily data yet. It will build up as you drive.")
                    .build()
            )
        }
        if (daysWithData.isNotEmpty()) {
            val vals = daysWithData.mapNotNull { it.substringAfter(":").toFloatOrNull() }
            val maxV = (vals.maxOrNull() ?: 0f).coerceAtLeast(15.6f)
            val titDays = if (es) "Por dia" else "Per day"
            // Gasto en euros. Cadena vacia si no hay precio configurado.
            val costRow = p.getString("cost_row", "") ?: ""
            if (costRow.isNotEmpty()) {
                list.addItem(
                    Row.Builder()
                        .setTitle(if (es) "Gasto" else "Cost")
                        .addText(costRow)
                        .build()
                )
            }
            list.addItem(Row.Builder().setTitle(titDays).addText(if (es) "Un dia por barra" else "One day per bar").build())
            for (d in daysWithData) {
                val label = d.substringBefore(":")
                val kwhStr = d.substringAfter(":")
                val kwh = kwhStr.toFloatOrNull() ?: continue
                val texto = bar(kwh, maxV) + "  " + kwhStr + " kWh/100"
                list.addItem(Row.Builder().setTitle(label).addText(texto).build())
            }
        }

        return ListTemplate.Builder()
            .setSingleList(list.build())
            .setTitle(if (es) "Consumo" else "Consumption")
            .setHeaderAction(Action.BACK)
            .build()
    }
}
