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
import android.os.Bundle
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

    // Sin esto el widget no se entera de que lo han redimensionado y sigue
    // pintando lo mismo ocupe lo que ocupe.
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        render(context, appWidgetManager, appWidgetId)
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
    }

    private fun render(context: Context, mgr: AppWidgetManager, widgetId: Int) {
        val p = HomeWidgetPlugin.getData(context)
        val v = RemoteViews(context.packageName, R.layout.quick_widget)

        // Tres tamanos, para poder ponerlo junto a otros widgets sin que se
        // coma media pantalla. El alto disponible lo informa el propio Android.
        //  - hasta 100dp: solo la barra y una fila de botones
        //  - hasta 160dp: mas datos y dos filas
        //  - por encima:  todo
        val alto = try {
            mgr.getAppWidgetOptions(widgetId)
                .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 180)
        } catch (_: Exception) {
            180
        }
        val compacto = alto < 100
        val medio = alto < 160

        val soc = p.getString("soc", null)
        val range = p.getString("range", null)
        val realRange = p.getString("realRange", null)
        val locked = p.getString("locked", null)
        val charging = p.getString("charging", null)
        val updated = p.getString("updated", null)
        val kw = p.getString("kw", null)

        val pct = soc?.toFloatOrNull()

        v.setTextViewText(R.id.qw_title,
            "LMB10" + (if (charging == "1") "  \u26A1" else "") +
            (if (locked == "1") "  \uD83D\uDD12" else ""))
        val ts = p.getString("updatedTs", null)?.toLongOrNull()
        val estado = p.getString("qw_status", "") ?: ""
        v.setTextViewText(R.id.qw_fresh,
            if (estado.isNotEmpty()) estado else antiguedad(ts, updated))
        v.setTextColor(R.id.qw_fresh, if (ts != null &&
                System.currentTimeMillis() - ts > 30 * 60 * 1000L)
            Color.parseColor("#B3341F") else Color.parseColor("#5B87AC"))

        // LINEA 1: lo que esta pasando AHORA. No se repite lo que ya da el
        // widget grande (autonomia, consumo, totales): aqui solo va lo que
        // sirve para decidir si hay que hacer algo con el coche.
        val temp = p.getString("batteryTemp", null)
        val tempTs = p.getString("batteryTempTs", null)?.toLongOrNull()
        val restante = p.getString("chargeRemainTime", null)?.toIntOrNull()
        val l1 = when {
            charging == "1" -> {
                val t = StringBuilder("Cargando")
                if (!kw.isNullOrEmpty()) t.append("  ").append(kw).append(" kW")
                if (restante != null && restante > 0) {
                    t.append("  ·  completa en ")
                    t.append(if (restante >= 60)
                        (restante / 60).toString() + " h " + (restante % 60).toString() + " min"
                        else restante.toString() + " min")
                }
                t.toString()
            }
            !temp.isNullOrEmpty() -> {
                val edad = if (tempTs != null) {
                    val h = (System.currentTimeMillis() - tempTs) / 3600000L
                    if (h >= 1L) "  (hace " + h + " h)" else ""
                } else ""
                "Bateria " + temp + "\u00B0" + edad
            }
            else -> ""
        }
        if (l1.isNotEmpty()) {
            v.setTextViewText(R.id.qw_info, l1)
            v.setViewVisibility(R.id.qw_info, View.VISIBLE)
        } else {
            v.setViewVisibility(R.id.qw_info, View.GONE)
        }

        // LINEA 2: ruedas. El rango entre la mas alta y la mas baja delata una
        // perdida lenta antes de que el coche llegue a avisar.
        val kpa = (p.getString("tireKpa", "") ?: "").split("|").mapNotNull { it.toIntOrNull() }
        val l2 = if (kpa.size >= 2) {
            val lo = kpa.min() / 100f
            val hi = kpa.max() / 100f
            if (kpa.min() == kpa.max())
                "Ruedas " + String.format("%.2f", lo).replace('.', ',') + " bar"
            else
                "Ruedas " + String.format("%.2f", lo).replace('.', ',') + " - " +
                String.format("%.2f", hi).replace('.', ',') + " bar"
        } else ""
        if (l2.isNotEmpty()) {
            v.setTextViewText(R.id.qw_info2, l2)
            v.setViewVisibility(R.id.qw_info2, View.VISIBLE)
        } else {
            v.setViewVisibility(R.id.qw_info2, View.GONE)
        }

        // Donde esta aparcado. Es la pregunta que mas veces hace mirar el
        // movil y no la responde ningun otro widget.
        val dir = p.getString("carAddress", null)
        if (!dir.isNullOrEmpty()) {
            v.setTextViewText(R.id.qw_info3, "\uD83D\uDCCD  " + dir)
            v.setViewVisibility(R.id.qw_info3, View.VISIBLE)
        } else {
            v.setViewVisibility(R.id.qw_info3, View.GONE)
        }

        // Aviso solo cuando hay algo que avisar. Un widget que siempre dice
        // "todo bien" deja de mirarse.
        val avisos = ArrayList<String>()
        val ruedasMal = (p.getString("tireAlerts", "") ?: "").split("|").filter { it.isNotEmpty() }
        val mant = p.getString("mant_aviso", "") ?: ""
        if (ruedasMal.isNotEmpty()) avisos.add("Presion: " + ruedasMal.joinToString(", "))
        if (locked == "0") avisos.add("El coche esta abierto")
        if (mant.isNotEmpty()) avisos.add(mant)
        if (avisos.isEmpty()) {
            v.setViewVisibility(R.id.qw_alert, View.GONE)
        } else {
            v.setTextViewText(R.id.qw_alert, "\u26A0  " + avisos.joinToString("  ·  "))
            v.setViewVisibility(R.id.qw_alert, View.VISIBLE)
        }

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

        // Estos tres abren fisicamente el coche. Van tambien por segundo plano:
        // el widget no se usa en la pantalla de bloqueo, asi que no hay motivo
        // para forzar el desbloqueo. El ambar sigue marcandolos como acciones
        // que abren el vehiculo.
        v.setOnClickPendingIntent(R.id.qw_openall,
            HomeWidgetBackgroundIntent.getBroadcast(
                context, Uri.parse("lmb10://action?cmd=openall")))
        v.setOnClickPendingIntent(R.id.qw_unlock,
            HomeWidgetBackgroundIntent.getBroadcast(
                context, Uri.parse("lmb10://action?cmd=unlock")))
        v.setOnClickPendingIntent(R.id.qw_trunk,
            HomeWidgetBackgroundIntent.getBroadcast(
                context, Uri.parse("lmb10://action?cmd=trunk")))

        v.setOnClickPendingIntent(R.id.qw_trunk_close,
            HomeWidgetBackgroundIntent.getBroadcast(
                context, Uri.parse("lmb10://action?cmd=trunk_close")))

        v.setOnClickPendingIntent(R.id.qw_defrost,
            HomeWidgetBackgroundIntent.getBroadcast(
                context, Uri.parse("lmb10://action?cmd=defrost")))
        v.setOnClickPendingIntent(R.id.qw_find,
            HomeWidgetBackgroundIntent.getBroadcast(
                context, Uri.parse("lmb10://action?cmd=find")))
        v.setOnClickPendingIntent(R.id.qw_wheel,
            HomeWidgetBackgroundIntent.getBroadcast(
                context, Uri.parse("lmb10://action?cmd=wheel_heat")))

        v.setOnClickPendingIntent(R.id.qw_root,
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))

        // Que se oculta en cada tamano
        v.setViewVisibility(R.id.qw_row2, if (compacto) View.GONE else View.VISIBLE)
        v.setViewVisibility(R.id.qw_row3, if (compacto || medio) View.GONE else View.VISIBLE)
        if (compacto) {
            v.setViewVisibility(R.id.qw_info, View.GONE)
            v.setViewVisibility(R.id.qw_info2, View.GONE)
            v.setViewVisibility(R.id.qw_info3, View.GONE)
        } else if (medio) {
            v.setViewVisibility(R.id.qw_info3, View.GONE)
        }

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
            f <= 0.15f -> Color.parseColor("#D3455B")
            f <= 0.35f -> Color.parseColor("#E0913B")
            else -> Color.parseColor("#1E9E88")
        }
        p.style = Paint.Style.FILL
        p.color = Color.parseColor("#A9CCE8")
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
            p.color = Color.WHITE
            c.drawText(txt, 22f, h - 24f, p)
        } else {
            p.color = Color.parseColor("#0D3B66")
            c.drawText(txt, w * f + 22f, h - 24f, p)
        }
        return bmp
    }
}
