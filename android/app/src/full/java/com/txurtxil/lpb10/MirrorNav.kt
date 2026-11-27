package com.txurtxil.lpb10

import android.content.ComponentName
import android.content.Intent
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.MessageTemplate
import androidx.car.app.model.Template

// Fusion espejo (flavor full): el menu "Espejo" abre la app LMonitor (port de
// MirrorMobile) EN EL TELEFONO. La integracion profunda de superficie en AA queda
// aparcada (guerra de driving-status con el host); esta via es simple y usa la app
// standalone que ya esta instalada. El usuario interactua con LMonitor en el movil.
object MirrorNav {
    const val ENABLED = true

    fun screen(ctx: CarContext): Screen {
        val message = openLMonitorOnPhone(ctx)
        return MessageScreen(ctx, message)
    }

    // Busca cualquier app LMonitor instalada (release o debug, con o sin sufijo)
    // y la lanza en el telefono. Devuelve el mensaje a mostrar en el coche.
    private fun openLMonitorOnPhone(ctx: CarContext): String {
        return try {
            val pm = ctx.packageManager
            val probe = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
            val target = pm.queryIntentActivities(probe, 0)
                .map { it.activityInfo }
                .firstOrNull { it.packageName.contains("lmonitor", ignoreCase = true) }
            if (target == null) {
                "No se encontro LMonitor instalada en el telefono."
            } else {
                val intent = Intent(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_LAUNCHER)
                    setComponent(ComponentName(target.packageName, target.name))
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                ctx.startActivity(intent)
                "LMonitor abierto en el telefono (" + target.packageName + "). Inicia el espejo desde la app."
            }
        } catch (e: Exception) {
            "No se pudo abrir LMonitor en el telefono: " + e.message
        }
    }

    private class MessageScreen(ctx: CarContext, private val message: String) : Screen(ctx) {
        override fun onGetTemplate(): Template =
            MessageTemplate.Builder(message)
                .setHeaderAction(Action.APP_ICON)
                .build()
    }
}
