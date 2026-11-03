// LockWidgetProvider v251: widget REAJUSTABLE. Encogido muestra 2 botones
// (cerrar/abrir); estirado, 4 (cerrar/abrir/maletero/todo). Ejecucion tipo
// v242: botones con HomeWidgetBackgroundIntent -> isolate de fondo de
// home_widget -> widgetActionCallback (ejecucion directa, sin confirmar).
// El estado se lee del dato qw_status. La altura minima del widget (dp,
// opcion OPTION_APPWIDGET_MIN_HEIGHT) decide el layout.
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
        val opts = mgr.getAppWidgetOptions(widgetId)
        val minH = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 40)
        val layout = if (minH >= 100) R.layout.lock_widget else R.layout.mini_lock_widget

        val p = HomeWidgetPlugin.getData(context)
        val v = RemoteViews(context.packageName, layout)
        v.setTextViewText(R.id.lw_status, p.getString("qw_status", "") ?: "")

        v.setOnClickPendingIntent(
            R.id.lw_btn_lock,
            HomeWidgetBackgroundIntent.getBroadcast(
                context, Uri.parse("lmb10://action?cmd=lock")))
        v.setOnClickPendingIntent(
            R.id.lw_btn_unlock,
            HomeWidgetBackgroundIntent.getBroadcast(
                context, Uri.parse("lmb10://action?cmd=unlock")))
        if (layout == R.layout.lock_widget) {
            v.setOnClickPendingIntent(
                R.id.lw_btn_trunk,
                HomeWidgetBackgroundIntent.getBroadcast(
                    context, Uri.parse("lmb10://action?cmd=trunk")))
            v.setOnClickPendingIntent(
                R.id.lw_btn_openall,
                HomeWidgetBackgroundIntent.getBroadcast(
                    context, Uri.parse("lmb10://action?cmd=openall")))
        }
        try { mgr.updateAppWidget(widgetId, v) } catch (_: Exception) {}
    }
}
