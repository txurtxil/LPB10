package com.txurtxil.lpb10

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.CarIcon
import androidx.car.app.model.Pane
import androidx.car.app.model.PaneTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import androidx.core.graphics.drawable.IconCompat
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Grafico de consumo por dia, como bitmap.
 *
 * Se cuelga EN LUGAR de ConsumoScreen desde el menu principal, y desde aqui se
 * llega al detalle en texto. Motivo: ConsumoScreen ya reventaba al pasar de 11
 * a 12 filas, y CarMainScreen va por 7. Meter filas en cualquiera de las dos
 * arriesga tumbar algo que ya funciona.
 *
 * El lienzo es CUADRADO aunque un grafico de barras pida apaisado: la ranura de
 * imagen del Pane recorta los laterales. Comprobado en el B10 el 30/07, con un
 * arco de 320x320 que se vio entero y una pila de 240x120 que salio cortada.
 */
class ConsumoChartScreen(carContext: CarContext) : Screen(carContext) {

    override fun onGetTemplate(): Template {
        val p = HomeWidgetPlugin.getData(carContext)
        val es = (p.getString("lang", "es") ?: "es").startsWith("es")
        val daysRaw = p.getString("cycle_days", "") ?: ""
        val avg7 = (p.getString("avg7_kwh100", "") ?: "").replace(",", ".").toFloatOrNull()

        // Formato por dia: dd/MM:kwh100:euros:km
        val dias = daysRaw.split(",")
            .filter { it.contains(":") }
            .mapNotNull { d ->
                val c = d.split(":")
                val v = c.getOrNull(1)?.replace(",", ".")?.toFloatOrNull()
                if (v == null || v <= 0f) null else Pair(c[0], v)
            }
            .takeLast(7)

        val pane = Pane.Builder()

        if (dias.isEmpty()) {
            pane.addRow(
                Row.Builder()
                    .setTitle(if (es) "Sin datos todavia" else "No data yet")
                    .addText(if (es) "Hacen falta dias con kilometros registrados."
                             else "Needs days with recorded kilometres.")
                    .build()
            )
        } else {
            try {
                pane.setImage(
                    CarIcon.Builder(IconCompat.createWithBitmap(dibuja(dias, avg7, es))).build()
                )
                CarLog.log(carContext, "GRAF", "bitmap ok, dias=" + dias.size)
            } catch (e: Exception) {
                CarLog.log(carContext, "GRAF", "bitmap fallo: " + e)
            }

            val mejor = dias.minByOrNull { it.second }
            val peor = dias.maxByOrNull { it.second }
            pane.addRow(
                Row.Builder()
                    .setTitle(if (es) "Media 7 dias" else "7-day average")
                    .addText(if (avg7 != null) fmt(avg7) + " kWh/100 km" else "--")
                    .build()
            )
            if (mejor != null && peor != null) {
                pane.addRow(
                    Row.Builder()
                        .setTitle(if (es) "Mejor y peor dia" else "Best and worst day")
                        .addText(mejor.first + ": " + fmt(mejor.second) +
                                 "   ·   " + peor.first + ": " + fmt(peor.second))
                        .build()
                )
            }
        }

        pane.addAction(
            Action.Builder()
                .setTitle(if (es) "Ver detalle" else "See detail")
                .setOnClickListener { screenManager.push(ConsumoScreen(carContext)) }
                .build()
        )

        return PaneTemplate.Builder(pane.build())
            .setTitle(if (es) "Consumo por dia" else "Consumption per day")
            .setHeaderAction(Action.BACK)
            .build()
    }

    private fun fmt(v: Float): String {
        val s = String.format("%.1f", v)
        return s.replace('.', ',')
    }

    private fun dibuja(dias: List<Pair<String, Float>>, avg: Float?, es: Boolean): Bitmap {
        val n = 480
        val bmp = Bitmap.createBitmap(n, n, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val p = Paint(Paint.ANTI_ALIAS_FLAG)

        val izq = 22f
        val der = n - 22f
        val arriba = 74f
        val abajo = n - 58f
        val alto = abajo - arriba

        val maxDato = dias.maxOf { it.second }
        val techo = (if (avg != null) maxOf(maxDato, avg) else maxDato) * 1.18f

        // La media va en la LEYENDA, no rotulada sobre su linea. En el coche,
        // el 30/07, las barras que valian casi lo mismo que la media pintaban
        // su etiqueta justo encima del rotulo y se solapaban los tres numeros.
        p.color = Color.WHITE
        p.textAlign = Paint.Align.LEFT
        p.textSize = 28f
        p.isFakeBoldText = true
        c.drawText("kWh/100 km", izq, 34f, p)
        p.isFakeBoldText = false
        if (avg != null && avg > 0f) {
            p.color = Color.parseColor("#CCFFFFFF")
            p.textSize = 24f
            c.drawText((if (es) "media " else "avg ") + fmt(avg), izq, 62f, p)
        }

        p.color = Color.parseColor("#44FFFFFF")
        p.strokeWidth = 2f
        c.drawLine(izq, abajo, der, abajo, p)

        val ancho = (der - izq) / dias.size
        val barra = ancho * 0.58f

        for (i in dias.indices) {
            val (etiqueta, valor) = dias[i]
            val cx = izq + ancho * i + ancho / 2f
            val h = (valor / techo) * alto
            val color = if (avg != null && valor > avg)
                Color.parseColor("#E9A23B") else Color.parseColor("#2A9D8F")

            p.style = Paint.Style.FILL
            p.color = color
            c.drawRoundRect(
                RectF(cx - barra / 2f, abajo - h, cx + barra / 2f, abajo), 7f, 7f, p)

            p.color = Color.WHITE
            p.textAlign = Paint.Align.CENTER
            p.textSize = 23f
            c.drawText(fmt(valor), cx, abajo - h - 10f, p)

            // Solo el dia del mes: "24/07" siete veces no cabe a este tamano y
            // las fechas acababan tocandose.
            p.color = Color.parseColor("#AAFFFFFF")
            p.textSize = 24f
            c.drawText(etiqueta.substringBefore("/"), cx, abajo + 30f, p)
        }

        // Linea de media sin rotulo, encima de las barras.
        if (avg != null && avg > 0f) {
            val y = abajo - (avg / techo) * alto
            p.style = Paint.Style.STROKE
            p.strokeWidth = 3f
            p.color = Color.parseColor("#DDFFFFFF")
            var x = izq
            while (x < der) {
                c.drawLine(x, y, minOf(x + 12f, der), y, p)
                x += 22f
            }
            p.style = Paint.Style.FILL
        }
        return bmp
    }
}