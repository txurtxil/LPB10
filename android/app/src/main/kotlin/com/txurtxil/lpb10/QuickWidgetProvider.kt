package com.txurtxil.lpb10

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.Color
import android.os.Bundle
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Widget de precio de la luz (PVPC). Sustituye al anterior widget de
 * acciones rapidas: aquel se traslado dentro de la app (pantalla Atajos)
 * para no tener botones que abran el coche en el escritorio.
 *
 * Este widget es SOLO LECTURA: no ejecuta ningun comando, asi que no tiene
 * ninguna de las consideraciones de seguridad del anterior.
 */
class QuickWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, mgr: AppWidgetManager, ids: IntArray) {
        for (id in ids) render(context, mgr, id)
    }

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

        val alto = try {
            mgr.getAppWidgetOptions(widgetId)
                .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 180)
        } catch (_: Exception) {
            180
        }
        val compacto = alto < 100
        val medio = alto < 160

        val ahora = p.getString("pvpc_ahora", null)
        val nivel = p.getString("pvpc_nivel", "")
        val horaBarata = p.getString("pvpc_hora_barata", null)
        val precioBarato = p.getString("pvpc_precio_barato", null)
        val baratoManana = p.getString("pvpc_barato_manana", "0") == "1"
        val horaCara = p.getString("pvpc_hora_cara", null)
        val precioCaro = p.getString("pvpc_precio_caro", null)

        if (ahora == null) {
            v.setTextViewText(R.id.qw_price_big, "-- €/kWh")
            v.setTextViewText(R.id.qw_price_label, "Sin datos todavia")
            v.setViewVisibility(R.id.qw_info, android.view.View.GONE)
            v.setViewVisibility(R.id.qw_info2, android.view.View.GONE)
            try { mgr.updateAppWidget(widgetId, v) } catch (_: Exception) {}
            return
        }

        val precioNum = ahora.toDoubleOrNull() ?: 0.0
        v.setTextViewText(R.id.qw_price_big, String.format("%.3f €/kWh", precioNum))

        val (etiqueta, color) = when (nivel) {
            "barato" -> "Barato ahora" to Color.parseColor("#1B7A3D")
            "caro"   -> "Caro ahora" to Color.parseColor("#B3341F")
            else     -> "Precio normal" to Color.parseColor("#144E7A")
        }
        v.setTextViewText(R.id.qw_price_label, etiqueta)
        v.setTextColor(R.id.qw_price_label, color)

        if (!compacto && horaBarata != null && precioBarato != null) {
            val hb = horaBarata.toIntOrNull() ?: 0
            val pb = precioBarato.toDoubleOrNull() ?: 0.0
            val dia = if (baratoManana) "mañana" else "hoy"
            v.setViewVisibility(R.id.qw_info, android.view.View.VISIBLE)
            v.setTextViewText(R.id.qw_info,
                String.format("Mas barato %s: %02dh (%.3f €)", dia, hb, pb))
        } else {
            v.setViewVisibility(R.id.qw_info, android.view.View.GONE)
        }

        if (!compacto && !medio && horaCara != null && precioCaro != null) {
            val hc = horaCara.toIntOrNull() ?: 0
            val pc = precioCaro.toDoubleOrNull() ?: 0.0
            v.setViewVisibility(R.id.qw_info2, android.view.View.VISIBLE)
            v.setTextViewText(R.id.qw_info2,
                String.format("Mas caro hoy: %02dh (%.3f €)", hc, pc))
        } else {
            v.setViewVisibility(R.id.qw_info2, android.view.View.GONE)
        }

        val gastoStr = p.getString("gasto_anual_total", null)
        val gastoNum = gastoStr?.toDoubleOrNull() ?: 0.0
        if (!compacto && !medio && gastoNum > 0) {
            v.setViewVisibility(R.id.qw_gasto, android.view.View.VISIBLE)
            v.setTextViewText(R.id.qw_gasto, String.format("Este ano: %.2f €", gastoNum))
        } else {
            v.setViewVisibility(R.id.qw_gasto, android.view.View.GONE)
        }

        v.setViewVisibility(R.id.qw_alert, if (compacto) android.view.View.GONE else android.view.View.VISIBLE)

        try { mgr.updateAppWidget(widgetId, v) } catch (_: Exception) {}
    }
}
