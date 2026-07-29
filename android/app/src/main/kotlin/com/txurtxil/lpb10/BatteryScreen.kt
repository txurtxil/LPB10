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
        val soc = p.getString("soc", null) ?: "--"
        val range = p.getString("range", null) ?: "--"
        val realRange = p.getString("realRange", null)
        val volt = p.getString("volt", null)
        val amp = p.getString("amp", null)
        val kw = p.getString("kw", null)?.toFloatOrNull()
        val temp = p.getString("interiorTemp", null)
        val batTemp = p.getString("batteryTemp", null)
        val batTempTs = p.getString("batteryTempTs", null)?.toLongOrNull()
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
        val batTempTxt = if (!batTemp.isNullOrEmpty()) {
            val ageMin = if (batTempTs != null && batTempTs > 0L)
                (System.currentTimeMillis() - batTempTs) / 60000L else -1L
            when {
                ageMin < 0L -> batTemp + " °C"
                ageMin < 20L -> batTemp + " °C"
                ageMin < 180L -> batTemp + " °C  (hace " + ageMin + " min)"
                else -> batTemp + " °C  (hace " + (ageMin / 60L) + " h)"
            }
        } else "-- (no reportada)"
        pane.addRow(
            Row.Builder()
                .setTitle("Temp. bateria")
                .addText(batTempTxt)
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
        // EXPERIMENTO. La conclusion previa de "Android Auto no admite
        // graficos" venia del WIDGET (RemoteViews no admite Canvas y los PNG
        // desaparecian), no de aqui: Android Auto nunca se llego a probar.
        // CarIcon si acepta IconCompat.createWithBitmap, asi que sobre el papel
        // esto deberia pintarse.
        //
        // Si el host lo rechaza, el catch deja el Pane sin imagen y la pantalla
        // sigue funcionando igual que antes. No tocar ninguna otra pantalla
        // hasta ver si esto aparece en la pantalla del coche.
        try {
            val pct = soc.toFloatOrNull()
            if (pct != null) {
                pane.setImage(CarIcon.Builder(
                    IconCompat.createWithBitmap(dibujaBateria(pct))).build())
                CarLog.log(carContext, "BAT", "bitmap adjuntado, soc=" + pct)
            }
        } catch (e: Exception) {
            CarLog.log(carContext, "BAT", "bitmap fallo: " + e)
        }

        return PaneTemplate.Builder(pane.build())
            .setTitle("Bateria")
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
    private fun dibujaBateria(pct: Float): Bitmap {
        val n = 320
        val bmp = Bitmap.createBitmap(n, n, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val p = Paint(Paint.ANTI_ALIAS_FLAG)
        val v = pct.coerceIn(0f, 100f)

        val color = when {
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
        p.textSize = 78f
        c.drawText(v.toInt().toString(), n / 2f, n / 2f + 12f, p)
        p.isFakeBoldText = false
        p.textSize = 30f
        p.color = Color.parseColor("#BBFFFFFF")
        c.drawText("%", n / 2f, n / 2f + 52f, p)
        return bmp
    }
}