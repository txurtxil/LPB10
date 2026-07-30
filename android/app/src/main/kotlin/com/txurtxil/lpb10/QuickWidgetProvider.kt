package com.txurtxil.lpb10

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Widget de acciones rapidas. Independiente de BatteryWidgetProvider, que se
 * queda como esta.
 *
 * SEGURIDAD, y es deliberado:
 *   - Cerrar y Clima van por HomeWidgetBackgroundIntent: ejecutan Dart en
 *     segundo plano sin abrir la app, asi que funcionan con el movil bloqueado.
 *     Dispararlas por error no tiene consecuencias.
 *   - Abrir y Maletero van por HomeWidgetLaunchIntent: lanzan la Activity, y
 *     Android la RETIENE detras del keyguard hasta que el usuario desbloquea.
 *     No hace falta programar ninguna comprobacion: la frontera de seguridad de
 *     Android hace el trabajo. Sin esto, cualquiera que cogiera el movil
 *     bloqueado podria abrir el coche desde la pantalla de bloqueo.
 *
 * El bitmap de la barra es un experimento: la creencia previa era que
 * RemoteViews no admitia imagenes, pero esa conclusion venia de un intento que
 * NUNCA se llego a cablear (chartPath se leia y no se usaba). Si falla, se
 * oculta la imagen y se muestra una barra de texto equivalente.
 */
class QuickWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, mgr: AppWidgetManager, ids: IntArray) {
        for (id in ids) render(context, mgr, id)
    }

    private fun render(context: Context, mgr: AppWidgetManager, widgetId: Int) {
        val p = HomeWidgetPlugin.getData(context)
        val v = RemoteViews(context.packageName, R.layout.quick_widget)

        val soc = p.getString("soc", null)
        val range = p.getString("range", null)
        val realRange = p.getString("realRange", null)
        val locked = p.getString("locked", null)
        val charging = p.getString("charging", null)
        val updated = p.getString("updated", null)
        val kw = p.getString("kw", null)

        val pct = soc?.toFloatOrNull()

        v.setTextViewText(R.id.qw_title,
            "LMB10" + (if (charging == "1") "  \u26A1" else ""))
        val ts = p.getString("updatedTs", null)?.toLongOrNull()
        v.setTextViewText(R.id.qw_fresh, antiguedad(ts, updated))
        v.setTextColor(R.id.qw_fresh, if (ts != null &&
                System.currentTimeMillis() - ts > 30 * 60 * 1000L)
            Color.parseColor("#E9A23B") else Color.parseColor("#8FA8BC"))

        val estado = when (locked) {
            "1" -> "Cerrado"; "0" -> "Abierto"; else -> "Estado desconocido"
        }
        val rangoTxt = when {
            !range.isNullOrEmpty() && !realRange.isNullOrEmpty() ->
                range + " km  ·  real ~" + realRange + " km"
            !range.isNullOrEmpty() -> range + " km"
            else -> "-- km"
        }
        v.setTextViewText(R.id.qw_info, rangoTxt)

        // Segunda linea: estado y lo que este pasando ahora mismo.
        val temp = p.getString("interiorTemp", null)
        val partes = ArrayList<String>()
        partes.add(estado)
        if (charging == "1" && !kw.isNullOrEmpty()) partes.add("cargando " + kw + " kW")
        if (!temp.isNullOrEmpty()) partes.add("interior " + temp + "\u00B0")
        v.setTextViewText(R.id.qw_info2, partes.joinToString("  ·  "))

        var pintado = false
        if (pct != null) {
            try {
                v.setImageViewBitmap(R.id.qw_bar_img, barra(pct))
                v.setViewVisibility(R.id.qw_bar_img, View.VISIBLE)
                v.setViewVisibility(R.id.qw_bar_txt, View.GONE)
                pintado = true
            } catch (_: Exception) { }
        }
        if (!pintado) {
            v.setViewVisibility(R.id.qw_bar_img, View.GONE)
            v.setViewVisibility(R.id.qw_bar_txt, View.VISIBLE)
            val n = ((pct ?: 0f) / 100f * 16f).toInt().coerceIn(0, 16)
            v.setTextViewText(R.id.qw_bar_txt,
                (if (pct != null) pct.toInt().toString() else "--") + "%  " +
                "\u2588".repeat(n) + "\u2591".repeat(16 - n))
        }

        // Sin abrir la app: funcionan con el movil bloqueado
        v.setOnClickPendingIntent(R.id.qw_lock,
            HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("lmb10://action?cmd=lock")))
        v.setOnClickPendingIntent(R.id.qw_clima,
            HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("lmb10://action?cmd=heat")))

        // Abren la app: Android las retiene tras el keyguard
        v.setOnClickPendingIntent(R.id.qw_unlock, HomeWidgetLaunchIntent.getActivity(
            context, MainActivity::class.java, Uri.parse("lmb10://action?cmd=unlock")))
        v.setOnClickPendingIntent(R.id.qw_trunk, HomeWidgetLaunchIntent.getActivity(
            context, MainActivity::class.java, Uri.parse("lmb10://action?cmd=trunk")))

        v.setOnClickPendingIntent(R.id.qw_root,
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))

        try { mgr.updateAppWidget(widgetId, v) } catch (_: Exception) { }
    }

    /** Antiguedad del dato en lenguaje llano. El TCU duerme a los ~13 min,
     *  asi que casi siempre se esta mirando una foto vieja: "hace 4 h" dice la
     *  verdad, "19:13" la disimula. */
    private fun antiguedad(ts: Long?, respaldo: String?): String {
        if (ts == null) return respaldo ?: ""
        val m = (System.currentTimeMillis() - ts) / 60000L
        return when {
            m < 0L -> respaldo ?: ""
            m < 2L -> "ahora"
            m < 60L -> "hace " + m + " min"
            m < 1440L -> "hace " + (m / 60L) + " h"
            else -> "hace " + (m / 1440L) + " d"
        }
    }

    private fun barra(pct: Float): Bitmap {
        val w = 520
        val h = 88
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val p = Paint(Paint.ANTI_ALIAS_FLAG)
        val f = pct.coerceIn(0f, 100f) / 100f
        val color = when {
            f <= 0.15f -> Color.parseColor("#E63946")
            f <= 0.35f -> Color.parseColor("#E9A23B")
            else -> Color.parseColor("#2A9D8F")
        }
        p.style = Paint.Style.FILL
        p.color = Color.parseColor("#1F3446")
        c.drawRoundRect(RectF(0f, 18f, w.toFloat(), h - 6f), 18f, 18f, p)
        p.color = color
        c.drawRoundRect(RectF(0f, 18f, w * f, h - 6f), 18f, 18f, p)

        // El numero va DENTRO de la parte llena si cabe, y fuera si no: con
        // bateria baja el texto blanco sobre fondo oscuro se leia mal.
        p.isFakeBoldText = true
        p.textSize = 44f
        p.textAlign = Paint.Align.LEFT
        val txt = pct.toInt().toString() + "%"
        val ancho = p.measureText(txt)
        if (w * f > ancho + 40f) {
            p.color = Color.parseColor("#0B1A18")
            c.drawText(txt, 22f, h - 24f, p)
        } else {
            p.color = Color.WHITE
            c.drawText(txt, w * f + 22f, h - 24f, p)
        }
        return bmp
    }
}
