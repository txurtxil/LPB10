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
 * Ruedas, con silueta del coche y la presion de cada una en su esquina.
 *
 * La version anterior pintaba una barra de bloques que NO media nada: era
 * binaria, llena si la rueda estaba bien y a medias si estaba en alerta,
 * porque solo llegaba tireAlerts con los nombres de las ruedas afectadas.
 * Ahora viajan tambien tireKpa y tireState desde Dart.
 *
 * Lienzo cuadrado: la ranura de imagen del Pane recorta los laterales.
 */
class TiresScreen(carContext: CarContext) : Screen(carContext) {

    override fun onGetTemplate(): Template {
        val p = HomeWidgetPlugin.getData(carContext)
        val es = (p.getString("lang", "es") ?: "es").startsWith("es")

        val kpa = (p.getString("tireKpa", "") ?: "").split("|")
        val estado = (p.getString("tireState", "") ?: "").split("|")
        val alertsRaw = p.getString("tireAlerts", "") ?: ""
        val alerts = alertsRaw.split("|").filter { it.isNotEmpty() }

        val valores = (0..3).map { kpa.getOrNull(it)?.toIntOrNull() }
        val malas = (0..3).map { (estado.getOrNull(it)?.toIntOrNull() ?: 0) != 0 }
        val hayDatos = valores.any { it != null }

        val medida = p.getString("tyre_size", "") ?: ""
        val recom = (p.getString("tyre_bar", "") ?: "").toFloatOrNull() ?: 0f

        val pane = Pane.Builder()

        if (hayDatos) {
            try {
                pane.setImage(
                    CarIcon.Builder(IconCompat.createWithBitmap(dibuja(valores, malas))).build())
                CarLog.log(carContext, "RUE", "bitmap ok, kpa=" + kpa.joinToString(","))
            } catch (e: Exception) {
                CarLog.log(carContext, "RUE", "bitmap fallo: " + e)
            }
        }

        val resumen = when {
            alerts.isNotEmpty() -> (if (es) "Revisa: " else "Check: ") + alerts.joinToString(", ")
            hayDatos -> if (es) "Las cuatro ruedas correctas" else "All four tyres OK"
            else -> if (es) "Sin lectura de presiones" else "No pressure readings"
        }
        pane.addRow(
            Row.Builder()
                .setTitle(if (es) "Estado" else "Status")
                .addText(resumen)
                .build()
        )

        if (hayDatos) {
            val leidas = valores.filterNotNull()
            val dif = if (leidas.size >= 2) leidas.max() - leidas.min() else 0
            val sb = StringBuilder()
            sb.append(dif.toString()).append(" kPa  ·  ").append(fmtBar(dif)).append(" bar")
            if (dif >= 20) {
                sb.append("\n").append(if (es)
                    "Una diferencia asi entre ruedas suele indicar una perdida lenta."
                    else "A spread like this usually means a slow leak.")
            }
            pane.addRow(
                Row.Builder()
                    .setTitle(if (es) "Diferencia entre ruedas" else "Spread between tyres")
                    .addText(sb.toString())
                    .build()
            )

            // Comparacion con la recomendada. Es el dato que de verdad dice si
            // hay que inflar: el coche solo avisa cuando ya esta muy baja.
            if (recom > 0f) {
                val mediaBar = leidas.average().toFloat() / 100f
                val delta = mediaBar - recom
                val txt = StringBuilder()
                txt.append(if (es) "Recomendada " else "Recommended ")
                txt.append(String.format("%.2f", recom).replace('.', ',')).append(" bar")
                txt.append("  ·  ")
                txt.append(when {
                    delta < -0.15f -> (if (es) "estas " else "you are ") +
                        String.format("%.2f", -delta).replace('.', ',') +
                        (if (es) " bar por debajo" else " bar below")
                    delta > 0.25f -> (if (es) "estas " else "you are ") +
                        String.format("%.2f", delta).replace('.', ',') +
                        (if (es) " bar por encima" else " bar above")
                    else -> if (es) "dentro de rango" else "within range"
                })
                pane.addRow(
                    Row.Builder()
                        .setTitle(if (es) "Frente a la recomendada" else "Against recommended")
                        .addText(txt.toString())
                        .build()
                )
            }

            // Medida y consejo. La presion sube al rodar, asi que una lectura
            // en caliente da de mas y no sirve para decidir si hay que inflar.
            val info = StringBuilder()
            if (medida.isNotEmpty()) info.append(medida).append("\n")
            info.append(if (es)
                "Mide en frio: rodando la presion sube unos 0,3 bar y parece correcta cuando no lo esta."
                else "Check cold: driving raises pressure by about 0.3 bar and hides a low tyre.")
            pane.addRow(
                Row.Builder()
                    .setTitle(if (es) "Neumaticos" else "Tyres")
                    .addText(info.toString())
                    .build()
            )
        } else {
            pane.addRow(
                Row.Builder()
                    .setTitle(if (es) "Sin datos" else "No data")
                    .addText(if (es)
                        "El coche no esta reportando presiones ahora mismo."
                        else "The car is not reporting pressures right now.")
                    .build()
            )
        }

        return PaneTemplate.Builder(pane.build())
            .setTitle(if (es) "Ruedas" else "Tyres")
            .setHeaderAction(Action.BACK)
            .build()
    }

    private fun fmtBar(kpa: Int): String =
        String.format("%.2f", kpa / 100f).replace('.', ',')

    private fun dibuja(v: List<Int?>, malas: List<Boolean>): Bitmap {
        val n = 480
        val bmp = Bitmap.createBitmap(n, n, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val p = Paint(Paint.ANTI_ALIAS_FLAG)

        p.style = Paint.Style.STROKE
        p.strokeWidth = 5f
        p.color = Color.parseColor("#55FFFFFF")
        c.drawRoundRect(RectF(160f, 78f, 320f, 402f), 58f, 58f, p)
        c.drawLine(240f, 150f, 240f, 330f, p)

        val posX = listOf(120f, 360f, 120f, 360f)
        val posY = listOf(150f, 150f, 330f, 330f)

        for (i in 0..3) {
            val lectura = v.getOrNull(i)
            val mala = malas.getOrNull(i) ?: false
            val color = when {
                lectura == null -> Color.parseColor("#66FFFFFF")
                mala -> Color.parseColor("#E63946")
                else -> Color.parseColor("#2A9D8F")
            }

            p.style = Paint.Style.FILL
            p.color = color
            c.drawRoundRect(
                RectF(posX[i] - 26f, posY[i] - 46f, posX[i] + 26f, posY[i] + 46f), 14f, 14f, p)

            p.color = Color.WHITE
            p.textAlign = Paint.Align.CENTER
            p.isFakeBoldText = true
            p.textSize = 34f
            c.drawText(if (lectura == null) "--" else fmtBar(lectura), posX[i], posY[i] + 82f, p)
            p.isFakeBoldText = false
            p.textSize = 20f
            p.color = Color.parseColor("#99FFFFFF")
            c.drawText("bar", posX[i], posY[i] + 106f, p)
        }
        return bmp
    }
}
