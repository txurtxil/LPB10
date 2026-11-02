// LockWidgetProvider v244: widget 2x2 (cerrar/abrir/maletero/todo).
// Los botones envian broadcast EXPLICITO a este provider (no home_widget):
// asi la CONFIRMACION es nativa y fiable (primer toque -> "Confirmar?" en el
// propio widget; segundo toque en <10 s -> ejecuta). La ejecucion encola la
// tarea WorkManager lmQuickActionTask, que ejecuta carQuickAction en el
// isolate de fondo (plugins registrados) y escribe el resultado en un fichero
// que este provider lee al repintar (las llamadas al plugin home_widget NO
// son fiables desde background isolate -> todo el feedback va por fichero).
package com.txurtxil.lpb10

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.RemoteViews
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequest
import androidx.work.OutOfQuotaPolicy
import androidx.work.WorkManager
import dev.fluttercommunity.workmanager.BackgroundWorker
import java.io.File
import java.util.concurrent.TimeUnit

class LockWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val CMD_ACTION = "com.txurtxil.lpb10.LOCKWIDGET_CMD"
        private const val RENDER_ACTION = "com.txurtxil.lpb10.LOCKWIDGET_RENDER"
        private const val PREF = "lockwidget_prefs"
        private const val KEY_ARMED = "armed_cmd"
        private const val KEY_ARMED_TS = "armed_ts"
        private const val RESULT_FILE = "lmb_widget_result.txt"
        private const val ARM_MS = 10_000L
        private const val RESULT_FRESH_MS = 120_000L
        private const val KEY_PENDING_UNTIL = "pending_until"
    }

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

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            RENDER_ACTION -> {
                val mgr = AppWidgetManager.getInstance(context)
                for (id in mgr.getAppWidgetIds(component(context))) {
                    render(context, mgr, id)
                }
            }
            CMD_ACTION -> handleCmd(context, intent)
        }
    }

    private fun component(context: Context) =
        android.content.ComponentName(context, LockWidgetProvider::class.java)

    private fun handleCmd(context: Context, intent: Intent) {
        val cmd = intent.getStringExtra("cmd") ?: return
        val widgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, -1)
        val mgr = AppWidgetManager.getInstance(context)
        val prefs = context.getSharedPreferences(PREF, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        val armed = prefs.getString(KEY_ARMED, null)
        val armedTs = prefs.getLong(KEY_ARMED_TS, 0)
        val fresh = armed == cmd && now - armedTs < ARM_MS

        if (cmd != "lock" && !fresh) {
            // Primer toque de una accion con confirmacion: armar + aviso nativo.
            prefs.edit().putString(KEY_ARMED, cmd).putLong(KEY_ARMED_TS, now).apply()
            setResetAlarm(context, widgetId, 12_000L)
            render(context, mgr, widgetId)
            return
        }
        // Ejecutar: lock siempre directo; el resto al confirmar (2o toque).
        prefs.edit().remove(KEY_ARMED).remove(KEY_ARMED_TS)
            .putLong(KEY_PENDING_UNTIL, now + 45_000L).apply()
        // v250 (decision owner, patron app oficial): abrir la app y ejecutar
        // la orden en PRIMER PLANO (se esquivan los limites de background).
        writeResult(context, "Abriendo app...")
        launchAppWithCmd(context, cmd)
        setResetAlarm(context, widgetId, 20_000L)
        render(context, mgr, widgetId)
    }

    private fun launchAppWithCmd(context: Context, cmd: String) {
        try {
            val i = Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                putExtra("lmb10_widget_cmd", cmd)
            }
            context.startActivity(i)
        } catch (e: Exception) {}
    }

    private fun setResetAlarm(context: Context, widgetId: Int, ms: Long) {
        try {
            val intent = Intent(RENDER_ACTION).setComponent(component(context))
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            val pi = PendingIntent.getBroadcast(
                context, 100 + (widgetId % 100), intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            am.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                System.currentTimeMillis() + ms,
                pi)
        } catch (e: Exception) {}
    }

    private fun render(context: Context, mgr: AppWidgetManager, widgetId: Int) {
        if (widgetId < 0) return
        val prefs = context.getSharedPreferences(PREF, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        val armed = prefs.getString(KEY_ARMED, null)
        val armedTs = prefs.getLong(KEY_ARMED_TS, 0)
        val armedFresh = armed != null && now - armedTs < ARM_MS
        if (armed != null && !armedFresh) {
            prefs.edit().remove(KEY_ARMED).remove(KEY_ARMED_TS).apply()
        }

        val v = RemoteViews(context.packageName, R.layout.lock_widget)
        val result = readResult(context)
        val pendingUntil = prefs.getLong(KEY_PENDING_UNTIL, 0)
        v.setTextViewText(R.id.lw_status, when {
            armedFresh -> "Confirmar ${labelOf(armed)}: toca otra vez"
            result != null -> result
            now < pendingUntil -> "Ejecutando..."
            else -> ""
        })
        v.setTextViewText(R.id.lw_lbl_lock, if (armedFresh) "Cerrar" else "Cerrar")
        v.setTextViewText(R.id.lw_lbl_unlock, labelFor(armedFresh, armed, "unlock", "Abrir"))
        v.setTextViewText(R.id.lw_lbl_trunk, labelFor(armedFresh, armed, "trunk", "Maletero"))
        v.setTextViewText(R.id.lw_lbl_openall, labelFor(armedFresh, armed, "openall", "Todo"))

        v.setOnClickPendingIntent(R.id.lw_btn_lock, cmdPending(context, widgetId, 1, "lock"))
        v.setOnClickPendingIntent(R.id.lw_btn_unlock, cmdPending(context, widgetId, 2, "unlock"))
        v.setOnClickPendingIntent(R.id.lw_btn_trunk, cmdPending(context, widgetId, 3, "trunk"))
        v.setOnClickPendingIntent(R.id.lw_btn_openall, cmdPending(context, widgetId, 4, "openall"))
        try { mgr.updateAppWidget(widgetId, v) } catch (e: Exception) {}
    }

    private fun labelFor(armedFresh: Boolean, armed: String?, cmd: String, base: String): String {
        if (!armedFresh || armed != cmd) return base
        return "$base ¿?"
    }

    private fun labelOf(cmd: String?): String = when (cmd) {
        "unlock" -> "ABRIR"
        "trunk" -> "MALETERO"
        "openall" -> "TODO"
        else -> "ACCION"
    }

    private fun cmdPending(context: Context, widgetId: Int, reqCode: Int, cmd: String): PendingIntent {
        val intent = Intent(CMD_ACTION).setComponent(component(context))
            .putExtra("cmd", cmd)
            .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
        return PendingIntent.getBroadcast(
            context, reqCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun writeResult(context: Context, text: String) {
        try {
            File(context.filesDir, RESULT_FILE).writeText(text.take(60))
        } catch (e: Exception) {}
    }

    private fun readResult(context: Context): String? {
        return try {
            val f = File(context.filesDir, RESULT_FILE)
            if (!f.exists()) return null
            if (System.currentTimeMillis() - f.lastModified() > RESULT_FRESH_MS) return null
            f.readText().trim().take(60).ifEmpty { null }
        } catch (e: Exception) { null }
    }
}
