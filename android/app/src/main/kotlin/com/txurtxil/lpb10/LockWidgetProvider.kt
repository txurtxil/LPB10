// lock_widget provider: widget 2x1 con dos botones: cerrar y abrir el coche.
// Los botones usan HomeWidgetBackgroundIntent (interactividad home_widget), que
// recoge HomeWidgetBackgroundReceiver y entrega el URI al callback de fondo
// registrado en Dart (widgetActionCallback -> carQuickAction, con doble toque
// de seguridad para abrir). El estado se lee del dato qw_status que el lado
// Dart escribe tras cada accion (aviso()).
package com.txurtxil.lpb10

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.net.Uri
import android.os.Bundle
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetPlugin

class LockWidgetProvider : AppWidgetProvider() {

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
        val v = RemoteViews(context.packageName, R.layout.lock_widget)

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
