// MiniLockWidgetProvider v245: widget 2x1 con DOS botones (cerrar/abrir),
// EXACTAMENTE como estaba en v242/v240: botones con HomeWidgetBackgroundIntent
// (URIs lmb10://action?cmd=lock|unlock) que entrega el tap al callback de
// fondo de Dart (doble toque para abrir) y estado desde el dato qw_status.
package com.txurtxil.lpb10

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetPlugin

class MiniLockWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, mgr: AppWidgetManager, ids: IntArray) {
        for (id in ids) render(context, mgr, id)
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle?
    ) {
        render(context, appWidgetManager, appWidgetId)
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
    }

    private fun render(context: Context, mgr: AppWidgetManager, widgetId: Int) {
        val p = HomeWidgetPlugin.getData(context)
        val v = RemoteViews(context.packageName, R.layout.mini_lock_widget)

        v.setTextViewText(R.id.lw_status, p.getString("qw_status", "") ?: "")

        v.setOnClickPendingIntent(
            R.id.lw_btn_lock,
            HomeWidgetBackgroundIntent.getBroadcast(
                context, Uri.parse("lmb10://action?cmd=lock"))
        )
        v.setOnClickPendingIntent(
            R.id.lw_btn_unlock,
            HomeWidgetBackgroundIntent.getBroadcast(
                context, Uri.parse("lmb10://action?cmd=unlock"))
        )
        try { mgr.updateAppWidget(widgetId, v) } catch (_: Exception) {}
    }
}
