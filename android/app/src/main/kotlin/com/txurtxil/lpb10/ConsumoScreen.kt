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

    // "km|kWh|euros" -> "265 km  ·  41,1 kWh  ·  5,34 EUR"
    // Los euros llegan vacios si no hay precio configurado.
    private fun fmtTot(raw: String): String {
        val c = raw.split("|")
        if (c.size < 2) return ""
        val base = c[0] + " km  \u00B7  " + c[1].replace('.', ',') + " kWh"
        val eur = if (c.size > 2) c[2] else ""
        return if (eur.isNotEmpty())
            base + "  \u00B7  " + eur.replace('.', ',') + " \u20AC"
        else base
    }

    override fun onGetTemplate(): Template {
        val p = HomeWidgetPlugin.getData(carContext)
        val es = (p.getString("lang", "es") ?: "es") == "es"
        val avg = p.getString("cycle_kwh100", "") ?: ""
        val estRange = p.getString("cycle_est_range", "") ?: ""
        val cycleKm = p.getString("cycle_km", "") ?: ""
        val daysRaw = p.getString("cycle_days", "") ?: ""
        // Objetivo y autonomia del perfil elegido. Antes iban 430 y 15,6
        // escritos a mano, asi que Android Auto mostraba las cifras del B10
        // aunque el usuario tuviera un C10.
        val maxRange = (p.getString("max_range_km", "") ?: "").toIntOrNull() ?: 430
        val target = (p.getString("target_kwh100", "") ?: "").toFloatOrNull() ?: 15.6f
        val targetTxt = String.format("%.1f", target).replace('.', ',')

        val list = ItemList.Builder()

        // --- RESUMEN DEL CICLO, ARRIBA ---
        val titSummary = if (es) "Ciclo actual" else "Current cycle"
        val summaryText = if (avg.isEmpty() || estRange.isEmpty()) {
            if (es) "Media: -- (datos insuficientes)" else "Average: -- (insufficient data)"
        } else {
            val est = estRange.toIntOrNull() ?: 0
            val diff = est - maxRange
            val rel = if (es) {
                if (diff >= 0) "+$diff km sobre objetivo" else "$diff km bajo objetivo"
            } else {
                if (diff >= 0) "+$diff km over target" else "$diff km under target"
            }
            val kmPart = if (cycleKm.isNotEmpty()) {
                if (es) "$cycleKm km en este ciclo\n" else "$cycleKm km this cycle\n"
            } else ""
            if (es)
                kmPart + "$avg kWh/100 · ~$estRange km reales\nObjetivo $maxRange km ($targetTxt): $rel"
            else
                kmPart + "$avg kWh/100 · ~$estRange km real\nTarget $maxRange km ($targetTxt): $rel"
        }
        list.addItem(Row.Builder().setTitle(titSummary).addText(summaryText).build())

        // Media de 7 dias: no depende del ciclo, asi que sigue habiendo cifra
        // aunque acabes de enchufar y el ciclo no tenga datos suficientes.
        val avg7 = p.getString("avg7_kwh100", "") ?: ""
        val tot7 = fmtTot(p.getString("tot_7d", "") ?: "")
        if (avg7.isNotEmpty() || tot7.isNotEmpty()) {
            val r = Row.Builder()
                .setTitle(if (es) "Ultimos 7 dias" else "Last 7 days")
            if (avg7.isNotEmpty()) r.addText(avg7 + " kWh/100")
            if (tot7.isNotEmpty()) r.addText(tot7)
            list.addItem(r.build())
        }

        // Mes y ano en UNA sola fila con dos lineas: cada fila cuenta para el
        // limite de elementos que impone el host, y ya vamos justos.
        val totMes = fmtTot(p.getString("tot_mes", "") ?: "")
        val totAno = fmtTot(p.getString("tot_ano", "") ?: "")
        if (totMes.isNotEmpty() || totAno.isNotEmpty()) {
            val r = Row.Builder().setTitle(if (es) "Totales" else "Totals")
            if (totMes.isNotEmpty())
                r.addText((if (es) "Mes: " else "Month: ") + totMes)
            if (totAno.isNotEmpty())
                r.addText((if (es) "Ano: " else "Year: ") + totAno)
            list.addItem(r.build())
        }

        // --- BARRAS POR DIA: solo dias CON dato real, para no ensuciar ---
        val allDays = daysRaw.split(",").filter { it.contains(":") }
        // Cada dia llega como "dd/MM:kwh100" o "dd/MM:kwh100:euros". El tercer
        // campo solo aparece si hay precio de la luz configurado, asi que hay
        // que partir por ':' y no usar substringAfter, que se comeria dos campos.
        val daysWithData = allDays.filter { it.split(":").getOrNull(1)?.toFloatOrNull() != null }
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
            val vals = daysWithData.mapNotNull { it.split(":").getOrNull(1)?.toFloatOrNull() }
            val maxV = (vals.maxOrNull() ?: 0f).coerceAtLeast(target)
            val titDays = if (es) "Por dia" else "Per day"
            // El gasto ya va dentro de las filas de 7 dias y Totales, asi que
            // aqui se aprovecha el hueco para explicar como se lee el grafico.
            list.addItem(
                Row.Builder()
                    .setTitle(if (es) "Como leer esto" else "How to read this")
                    .addText(if (es)
                        "La barra compara cada dia con el que mas gasto de la semana: llena = el peor."
                        else "The bar compares each day with the worst one of the week: full = worst.")
                    .addText(if (es)
                        "kWh/100 = energia gastada cada 100 km. Cuanto menos, mejor. Objetivo $targetTxt."
                        else "kWh/100 = energy used per 100 km. Lower is better. Target $targetTxt.")
                    .build()
            )
            list.addItem(Row.Builder().setTitle(titDays).addText(if (es) "Un dia por barra" else "One day per bar").build())
            for (d in daysWithData) {
                val campos = d.split(":")
                val label = campos.getOrNull(0) ?: continue
                val kwhStr = campos.getOrNull(1) ?: continue
                val kwh = kwhStr.toFloatOrNull() ?: continue
                val eur = campos.getOrNull(2) ?: ""
                val kmDia = campos.getOrNull(3) ?: ""
                val sb = StringBuilder()
                sb.append(bar(kwh, maxV)).append("  ").append(kwhStr).append(" kWh/100")
                if (kmDia.isNotEmpty()) sb.append("  \u00B7  ").append(kmDia).append(" km")
                if (eur.isNotEmpty())
                    sb.append("  \u00B7  ").append(eur.replace('.', ',')).append(" \u20AC")
                val texto = sb.toString()
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
