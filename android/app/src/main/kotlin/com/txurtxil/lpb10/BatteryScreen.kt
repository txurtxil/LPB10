package com.txurtxil.lpb10

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.core.graphics.drawable.IconCompat
import androidx.car.app.model.Action
import androidx.car.app.model.CarIcon
import androidx.car.app.model.Pane
import androidx.car.app.model.PaneTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import es.antonborri.home_widget.HomeWidgetPlugin

class BatteryScreen(carContext: CarContext) : Screen(carContext) {
    override fun onGetTemplate(): Template {
        val p = HomeWidgetPlugin.getData(carContext)
        val es = (p.getString("lang", "es") ?: "es").startsWith("es")

        val soc = p.getString("soc", "") ?: ""
        val pct = soc.toFloatOrNull()
        val range = p.getString("range", "") ?: ""
        val realRange = p.getString("realRange", "") ?: ""
        val kw = p.getString("kw", "") ?: ""
        val volt = p.getString("volt", "") ?: ""
        val amp = p.getString("amp", "") ?: ""
        val tInt = p.getString("interiorTemp", "") ?: ""
        val tBat = p.getString("batteryTemp", "") ?: ""
        val tBatTs = p.getString("batteryTempTs", "")?.toLongOrNull()
        val restante = p.getString("chargeRemainTime", "")?.toIntOrNull()
        val cargando = (p.getString("charging", "") ?: "") == "1"

        // Ficha del perfil elegido. El coche no reporta nada de esto.
        val chem = p.getString("bat_chem", "") ?: ""
        val dcKw = p.getString("bat_dc_kw", "")?.toIntOrNull() ?: 0
        val acKw = p.getString("bat_ac_kw", "")?.toIntOrNull() ?: 0
        val capKwh = p.getString("bat_kwh", "") ?: ""
        val limite = p.getString("charge_limit", "") ?: ""
        val ventana = p.getString("charge_window", "") ?: ""

        val pane = Pane.Builder()

        // --- 1. CARGA ---
        val cargaTxt = StringBuilder()
        if (pct != null) cargaTxt.append(String.format("%.1f", pct).replace('.', ',')).append(" %")
        if (range.isNotEmpty()) {
            cargaTxt.append("  \u00B7  ").append(range).append(" km")
            if (realRange.isNotEmpty()) cargaTxt.append(" / real ~").append(realRange).append(" km")
        }
        if (pct != null && capKwh.isNotEmpty()) {
            val cap = capKwh.toFloatOrNull()
            if (cap != null) cargaTxt.append("\n")
                .append(String.format("%.1f", cap * pct / 100f).replace('.', ','))
                .append(" de ").append(capKwh.replace('.', ',')).append(" kWh disponibles")
        }
        pane.addRow(Row.Builder()
            .setTitle(if (es) "Carga" else "Charge")
            .addText(cargaTxt.toString()).build())

        // --- 2. LO QUE PASA AHORA ---
        val ahora = StringBuilder()
        if (kw.isNotEmpty()) {
            ahora.append(kw.replace('.', ',')).append(" kW")
            if (cargando && restante != null && restante > 0) {
                ahora.append("  \u00B7  ").append(if (es) "completa en " else "full in ")
                ahora.append(if (restante >= 60)
                    (restante / 60).toString() + " h " + (restante % 60).toString() + " min"
                    else restante.toString() + " min")
            }
        }
        if (volt.isNotEmpty() && amp.isNotEmpty())
            ahora.append("\n").append(volt).append(" V  \u00B7  ").append(amp).append(" A")
        if (ahora.isNotEmpty()) {
            pane.addRow(Row.Builder()
                .setTitle(if (es) "Ahora mismo" else "Right now")
                .addText(ahora.toString()).build())
        }

        // --- 3. TEMPERATURAS ---
        val temps = StringBuilder()
        if (tBat.isNotEmpty()) {
            temps.append(if (es) "Bateria " else "Battery ").append(tBat).append(" \u00B0C")
            if (tBatTs != null) {
                val h = (System.currentTimeMillis() - tBatTs) / 3600000L
                if (h >= 1L) temps.append(if (es) "  (hace " else "  (") .append(h).append(if (es) " h)" else " h ago)")
            }
        }
        if (tInt.isNotEmpty()) {
            if (temps.isNotEmpty()) temps.append("  \u00B7  ")
            temps.append(if (es) "interior " else "cabin ").append(tInt).append(" \u00B0C")
        }
        if (temps.isNotEmpty()) {
            pane.addRow(Row.Builder()
                .setTitle(if (es) "Temperatura" else "Temperature")
                .addText(temps.toString()).build())
        }

        // --- 4. FICHA Y CONSEJO ---
        // Toda la gama Leapmotor monta LFP. Esa quimica prefiere cargas al 100%
        // con regularidad, al reves que las NMC de otras marcas: mucha gente
        // aplica la regla del 80% por costumbre y aqui es contraproducente.
        val ficha = StringBuilder()
        if (chem.isNotEmpty()) {
            ficha.append(chem)
            if (dcKw > 0) ficha.append("  \u00B7  ").append(dcKw).append(" kW CC")
            if (acKw > 0) ficha.append(" / ").append(acKw).append(" kW CA")
        }
        if (limite.isNotEmpty()) {
            if (ficha.isNotEmpty()) ficha.append("\n")
            ficha.append(if (es) "Limite de carga " else "Charge limit ").append(limite).append(" %")
            if (ventana.isNotEmpty() && ventana != "-") ficha.append("  \u00B7  ").append(ventana)
        }
        if (chem == "LFP") {
            if (ficha.isNotEmpty()) ficha.append("\n")
            ficha.append(if (es)
                "En LFP conviene cargar al 100 % de vez en cuando; no le perjudica."
                else "With LFP it is good to charge to 100 % now and then.")
        }
        if (ficha.isNotEmpty()) {
            pane.addRow(Row.Builder()
                .setTitle(if (es) "Bateria" else "Battery")
                .addText(ficha.toString()).build())
        }

        if (pct != null) {
            try {
                pane.setImage(CarIcon.Builder(
                    IconCompat.createWithBitmap(dibujaBateria(pct, cargando))).build())
            } catch (e: Exception) {
                CarLog.log(carContext, "BAT", "bitmap fallo: " + e)
            }
        }

        return PaneTemplate.Builder(pane.build())
            .setTitle(if (es) "Bateria" else "Battery")
            .setHeaderAction(Action.BACK)
            .build()
    }

    /// Arco de carga, 320x320.
    ///
    /// La version anterior era una pila horizontal de 240x120 y el host del B10
    /// la RECORTABA por los laterales: se perdian las esquinas redondeadas y el
    /// terminal. No se sabe cuanto recorta ni si depende del coche, asi que en
    /// vez de ajustar margenes a ciegas se usa una forma TOLERANTE al recorte:
    /// un arco centrado solo pierde los extremos y nunca parece roto.
    private fun dibujaBateria(pct: Float, cargando: Boolean): Bitmap {
        val n = 320
        val bmp = Bitmap.createBitmap(n, n, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val p = Paint(Paint.ANTI_ALIAS_FLAG)
        val v = pct.coerceIn(0f, 100f)

        val color = when {
            cargando -> Color.parseColor("#2A6FD0")
            v <= 15f -> Color.parseColor("#E63946")
            v <= 35f -> Color.parseColor("#E9A23B")
            else -> Color.parseColor("#2A9D8F")
        }

        val r = 108f
        val caja = RectF(n / 2f - r, n / 2f - r, n / 2f + r, n / 2f + r)
        p.style = Paint.Style.STROKE
        p.strokeWidth = 26f
        p.strokeCap = Paint.Cap.ROUND

        p.color = Color.parseColor("#33FFFFFF")
        c.drawArc(caja, 135f, 270f, false, p)
        p.color = color
        c.drawArc(caja, 135f, 270f * (v / 100f), false, p)

        p.style = Paint.Style.FILL
        p.color = Color.WHITE
        p.textAlign = Paint.Align.CENTER
        p.isFakeBoldText = true
        p.textSize = 72f
        c.drawText(String.format("%.1f", v).replace('.', ','), n / 2f, n / 2f + 12f, p)
        p.isFakeBoldText = false
        p.textSize = 30f
        p.color = Color.parseColor("#BBFFFFFF")
        c.drawText("%", n / 2f, n / 2f + 52f, p)
        return bmp
    }
}