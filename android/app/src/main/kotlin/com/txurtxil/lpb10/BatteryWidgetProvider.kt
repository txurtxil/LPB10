package com.txurtxil.lpb10
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class BatteryWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) render(context, appWidgetManager, id)
    }

    override fun onAppWidgetOptionsChanged(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int, newOptions: Bundle) {
        render(context, appWidgetManager, appWidgetId)
    }

    private fun render(context: Context, mgr: AppWidgetManager, widgetId: Int) {
        val prefs = HomeWidgetPlugin.getData(context)
        val views = RemoteViews(context.packageName, R.layout.battery_widget)

        val minH = try {
            mgr.getAppWidgetOptions(widgetId).getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 180)
        } catch (_: Exception) { 180 }
        val tiny = minH < 90
        val large = minH >= 170

        val soc = prefs.getString("soc", null)
        val range = prefs.getString("range", null)
        val realRange = prefs.getString("realRange", null)
        val cycleKm = prefs.getString("cycleKm", null)
        val locked = prefs.getString("locked", null)
        val updated = prefs.getString("updated", null)
        val charging = prefs.getString("charging", null)
        val lastCharge = prefs.getString("lastCharge", null)
        val chartPath = prefs.getString("chartPath", null)

        views.setTextViewText(R.id.widget_soc, if (soc != null) "$soc%" else "--%")
        // Linea 1: lo que QUEDA (autonomia). Linea 2: lo RECORRIDO (ciclo).
        // Antes se mezclaban autonomia y recorrido en una sola linea, lo que
        // parecia contradictorio (miden cosas distintas).
        val quedanText = when {
            range != null && !realRange.isNullOrEmpty() -> "Quedan: $range km (real ~$realRange)"
            range != null -> "Quedan: $range km"
            else -> "Quedan: -- km"
        }
        val recorridoText = when {
            cycleKm == "pocos datos" -> "Recorrido: -- (pocos datos)"
            !cycleKm.isNullOrEmpty() -> "Recorrido: $cycleKm km desde la carga"
            else -> "Recorrido: -- km"
        }
        views.setTextViewText(R.id.widget_range, quedanText + "\n" + recorridoText)
        views.setTextViewText(R.id.widget_lock, when (locked) {
            "1" -> "Cerrado"
            "0" -> "Abierto"
            else -> "Estado desconocido"
        })
        views.setTextViewText(R.id.widget_updated, updated ?: "")

        val chargeText = when {
            charging == "1" -> "\u26A1 Cargando..."
            !lastCharge.isNullOrEmpty() -> "\u26A1 " + lastCharge
            else -> null
        }

        views.setViewVisibility(R.id.widget_lock, if (tiny) View.GONE else View.VISIBLE)
        views.setViewVisibility(R.id.widget_updated, if (tiny) View.GONE else View.VISIBLE)
        if (!tiny && chargeText != null) {
            views.setTextViewText(R.id.widget_charge, chargeText)
            views.setViewVisibility(R.id.widget_charge, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_charge, View.GONE)
        }

        val chartText = prefs.getString("chartText", null)
        if (large && !chartText.isNullOrEmpty()) {
            views.setTextViewText(R.id.widget_chart_text, chartText)
            views.setViewVisibility(R.id.widget_chart_text, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_chart_text, View.GONE)
        }

        val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
        views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
        views.setOnClickPendingIntent(R.id.widget_title, pendingIntent)
        val refreshIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
        views.setOnClickPendingIntent(R.id.widget_refresh, refreshIntent)

        // Botones de rutinas favoritas (deep link lmb10://routine?id=<id>)
        val fav1Name = prefs.getString("fav1_name", null)
        val fav1Id = prefs.getString("fav1_id", null)
        val fav2Name = prefs.getString("fav2_name", null)
        val fav2Id = prefs.getString("fav2_id", null)
        if (!tiny && !fav1Name.isNullOrEmpty() && !fav1Id.isNullOrEmpty()) {
            views.setViewVisibility(R.id.widget_routines_row, View.VISIBLE)
            views.setTextViewText(R.id.widget_routine1, fav1Name)
            val i1 = HomeWidgetLaunchIntent.getActivity(
                context, MainActivity::class.java, Uri.parse("lmb10://routine?id=$fav1Id"))
            views.setOnClickPendingIntent(R.id.widget_routine1, i1)
            if (!fav2Name.isNullOrEmpty() && !fav2Id.isNullOrEmpty()) {
                views.setViewVisibility(R.id.widget_routine2, View.VISIBLE)
                views.setTextViewText(R.id.widget_routine2, fav2Name)
                val i2 = HomeWidgetLaunchIntent.getActivity(
                    context, MainActivity::class.java, Uri.parse("lmb10://routine?id=$fav2Id"))
                views.setOnClickPendingIntent(R.id.widget_routine2, i2)
            } else {
                views.setViewVisibility(R.id.widget_routine2, View.GONE)
            }
        } else {
            views.setViewVisibility(R.id.widget_routines_row, View.GONE)
        }
        try { mgr.updateAppWidget(widgetId, views) } catch (_: Exception) { }
    }
}
