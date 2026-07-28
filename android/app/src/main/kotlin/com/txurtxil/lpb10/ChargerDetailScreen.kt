package com.txurtxil.lpb10

import android.app.KeyguardManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.car.app.CarContext
import androidx.car.app.CarToast
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.MessageTemplate
import androidx.car.app.model.Pane
import androidx.car.app.model.PaneTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template

/**
 * Detalle de un cargador con DOS vias de navegacion distintas.
 *
 * Contexto (log del coche, 26/07): startCarApp(ACTION_NAVIGATE) devuelve sin
 * excepcion pero el host del B10 no abre nada. El log tampoco muestra un
 * onCreateScreen posterior, asi que el host NO nos devuelve el intent a
 * nosotros mismos: simplemente lo descarta en silencio. Al no haber señal de
 * fallo, no se pueden encadenar reintentos automaticos; se ofrecen las dos
 * rutas y cada una deja traza en el log.
 */
class ChargerDetailScreen(
    carContext: CarContext,
    private val c: CarCharger
) : Screen(carContext) {

    // Via 1: el host del coche. URI "geo:lat,lon" = ir a un punto. Antes se
    // mandaba "geo:0,0?q=..." que es la forma de BUSQUEDA, no la de destino.
    // Sin usar desde la interfaz: en el B10 startCarApp devuelve sin excepcion
    // y no abre nada (log del 26 y 27/07, siete intentos). Se conserva por si
    // algun dia se prueba a cambiar la categoria del manifest a CHARGING, que
    // es el caso de uso para el que Google diseno este traspaso.
    private fun viaHost() {
        val uri = Uri.parse("geo:" + c.lat + "," + c.lon)
        try {
            CarLog.log(carContext, "NAV", "HOST intento " + uri)
            carContext.startCarApp(Intent(CarContext.ACTION_NAVIGATE, uri))
            CarLog.log(carContext, "NAV", "HOST sin excepcion")
        } catch (e: Exception) {
            CarLog.log(carContext, "NAV", "HOST fallo: " + e.javaClass.simpleName + " " + e.message)
            CarToast.makeText(carContext, "El coche no acepto la navegacion", CarToast.LENGTH_LONG).show()
        }
    }

    // Via 2: salta el host y lanza Maps en el movil. Con Android Auto
    // conectado, Maps se proyecta en la pantalla del coche. Puede fallar por
    // las restricciones de arranque de actividades en segundo plano.
    private fun viaPhone() {
        // Con el movil bloqueado Android NO abre Google Maps: encola la
        // actividad detras del keyguard y la suelta al desbloquear. No hay
        // forma de saltarselo desde una app de terceros, asi que se avisa.
        val kg = carContext.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
        if (kg != null && kg.isKeyguardLocked) {
            CarLog.log(carContext, "NAV", "MOVIL abortado: keyguard bloqueado")
            screenManager.push(LockedScreen(carContext) { viaPhone() })
            return
        }
        val nav = Uri.parse("google.navigation:q=" + c.lat + "," + c.lon)
        try {
            CarLog.log(carContext, "NAV", "MOVIL intento " + nav)
            val i = Intent(Intent.ACTION_VIEW, nav)
            i.setPackage("com.google.android.apps.maps")
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            // carContext.startActivity() arrastra el display del COCHE. El log
            // del 26/07 lo dejo claro: SecurityException Permission Denial con
            // launchDisplayId=98, porque solo las apps aprobadas para
            // automocion pueden abrir actividades en esa pantalla.
            // Con applicationContext la actividad va al display del movil, y
            // Android Auto proyecta Maps por su cuenta.
            carContext.applicationContext.startActivity(i)
            CarLog.log(carContext, "NAV", "MOVIL lanzado con Maps (display movil)")
            // Comprobado en el B10 el 27/07: Maps arranca en el movil Y la ruta
            // queda cargada en el Maps de Android Auto. Lo unico que falta es
            // que el usuario cambie de app en la pantalla del coche, y eso no
            // hay forma de automatizarlo: la API para traer otra app al frente
            // es startCarApp(ACTION_NAVIGATE), y el host del B10 la descarta.
            screenManager.push(NavSentScreen(carContext, c.name))
        } catch (e: ActivityNotFoundException) {
            CarLog.log(carContext, "NAV", "MOVIL sin Maps, reintento generico")
            try {
                val g = Intent(Intent.ACTION_VIEW,
                    Uri.parse("geo:" + c.lat + "," + c.lon + "?q=" + c.lat + "," + c.lon))
                g.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                carContext.applicationContext.startActivity(g)
                CarLog.log(carContext, "NAV", "MOVIL lanzado generico (display movil)")
            } catch (e2: Exception) {
                CarLog.log(carContext, "NAV", "MOVIL fallo: " + e2.javaClass.simpleName + " " + e2.message)
                CarToast.makeText(carContext, "No hay app de mapas", CarToast.LENGTH_LONG).show()
            }
        } catch (e: Exception) {
            CarLog.log(carContext, "NAV", "MOVIL fallo: " + e.javaClass.simpleName + " " + e.message)
            CarToast.makeText(carContext, "Android bloqueo la apertura", CarToast.LENGTH_LONG).show()
        }
    }

    private class LockedScreen(
        carContext: CarContext,
        private val onRetry: () -> Unit
    ) : Screen(carContext) {
        override fun onGetTemplate(): Template {
            return MessageTemplate.Builder(
                "El movil esta bloqueado y Android no deja abrir Google Maps " +
                    "hasta desbloquearlo.\n\nDesbloquea la pantalla del movil " +
                    "y pulsa Reintentar."
            )
                .setTitle("Movil bloqueado")
                .setHeaderAction(Action.BACK)
                .addAction(
                    Action.Builder()
                        .setTitle("Reintentar")
                        .setOnClickListener {
                            screenManager.pop()
                            onRetry()
                        }
                        .build()
                )
                .build()
        }
    }

    private class NavSentScreen(
        carContext: CarContext,
        private val destino: String
    ) : Screen(carContext) {
        override fun onGetTemplate(): Template {
            return MessageTemplate.Builder(
                "Ruta a " + destino + " enviada a Google Maps.\n\n" +
                    "Abre Maps en la pantalla del coche para verla."
            )
                .setTitle("Ruta enviada")
                .setHeaderAction(Action.BACK)
                .addAction(
                    Action.Builder()
                        .setTitle("Entendido")
                        .setOnClickListener { screenManager.pop() }
                        .build()
                )
                .build()
        }
    }

    override fun onGetTemplate(): Template {
        val km = String.format("%.1f km", c.distM / 1000f)
        val pane = Pane.Builder()
        pane.addRow(Row.Builder().setTitle("Distancia").addText(km).build())
        pane.addRow(
            Row.Builder()
                .setTitle("Coordenadas")
                .addText(c.lat.toString() + ", " + c.lon.toString())
                .build()
        )
        if (c.info.isNotEmpty()) {
            pane.addRow(Row.Builder().setTitle("Operador").addText(c.info).build())
        }
        pane.addAction(
            Action.Builder()
                .setTitle("Maps del coche")
                .setOnClickListener { viaHost() }
                .build()
        )
        pane.addAction(
            Action.Builder()
                .setTitle("Enviar a Maps")
                .setOnClickListener { viaPhone() }
                .build()
        )
        return PaneTemplate.Builder(pane.build())
            .setTitle(c.name)
            .setHeaderAction(Action.BACK)
            .build()
    }
}
