package com.txurtxil.lpb10

import android.content.Intent
import androidx.car.app.CarAppService
import androidx.car.app.Screen
import androidx.car.app.Session
import androidx.car.app.validation.HostValidator

/**
 * Servicio Android Auto. Categoria POI (puntos de interes), la unica
 * abierta a apps de terceros que no sean del fabricante del coche:
 * Google NO permite mostrar datos del vehiculo (bateria, ruedas,
 * consumo, acciones) en pantallas de Auto a apps no-OEM.
 *
 * Por eso la raiz es directamente la lista de cargadores cercanos
 * (ChargersScreen -> ChargerDetailScreen -> navegar con Maps).
 * Las pantallas antiguas con datos del coche se retiraron de esta rama.
 */
open class LMB10CarAppService : CarAppService() {
    override fun createHostValidator(): HostValidator =
        // v-next (2026-11-07, issue #15): APP DISTRIBUIDA POR APK DIRECTA,
        // sin certificar en Play (decision del owner). El allowlist de
        // muestra solo acepta el DHU de escritorio; en el coche real el
        // host de Google quedaria rechazado. Sideloaded => aceptamos
        // cualquier host (el canal host<->app ya lo autentica el propio
        // Android Auto del telefono). Si algun dia esto vuelve a Play,
        // revertir al hosts_allowlist_sample certificado.
        HostValidator.ALLOW_ALL_HOSTS_VALIDATOR

    override fun onCreate() {
        super.onCreate()
        CarLog.log(this, "SERVICE", this.javaClass.simpleName + " onCreate")
        // v3.60.193: sin adb, el carlog es la unica ventana a los fallos en
        // la unidad real. Toda excepcion no capturada del proceso se anota
        // aqui (con las primeras lineas de stack) antes de morir.
        val previo = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { hilo, err ->
            try {
                CarLog.log(this, "SERVICE", "EXCEPCION NO CAPTURADA hilo=" +
                    hilo.name + " " + err.javaClass.simpleName + ": " + err.message)
                err.stackTrace.take(12).forEach {
                    CarLog.log(this, "SERVICE", "  en " + it.toString())
                }
            } catch (_: Throwable) {
            }
            if (previo != null) {
                previo.uncaughtException(hilo, err)
            } else {
                android.os.Process.killProcess(android.os.Process.myPid())
            }
        }
    }

    override fun onCreateSession(): Session = object : Session() {
        override fun onCreateScreen(intent: Intent): Screen {
            CarLog.log(carContext, "SERVICE",
                "onCreateScreen action=" + intent.action + " data=" + intent.data)
            // Raiz: hub principal del coche (bateria, consumo, ruedas,
            // acciones rapidas, rutinas, cargadores...). Rescate 2026-11-07
            // de la suite completa de septiembre (a59a54c^): se habia
            // reducido a cargadores SOLO por politica de Google Play;
            // esta variante no va por Play (issue #15).
            return CarMainScreen(carContext)
        }

        // Cuando el host entrega un intent a una sesion YA VIVA no llama a
        // onCreateScreen: llama aqui. Con la categoria POI el host no nos
        // devuelve los ACTION_NAVIGATE (los resuelve Maps), pero si algun dia
        // aparece un intent inesperado, la traza sale por aqui.
        override fun onNewIntent(intent: Intent) {
            CarLog.log(carContext, "SERVICE",
                "onNewIntent action=" + intent.action + " data=" + intent.data)
        }
    }
}
