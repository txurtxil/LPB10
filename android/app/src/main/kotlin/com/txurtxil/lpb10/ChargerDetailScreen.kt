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
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.MessageTemplate
import androidx.car.app.model.Pane
import androidx.car.app.model.PaneTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template

/**
 * Detalle de un cargador con DOS vias de navegacion distintas.
 *
 * Historia, porque costo dos dias de diagnostico equivocado:
 * startCarApp(ACTION_NAVIGATE) devolvia sin excepcion y no abria nada. Se
 * concluyo que el host lo descartaba en silencio, porque no aparecia ningun
 * onCreateScreen posterior en el log. La conclusion era FALSA: cuando el host
 * entrega un intent a una sesion YA VIVA no llama a onCreateScreen, llama a
 * Session.onNewIntent(), que no estaba instrumentado. Se estaba mirando el
 * metodo equivocado.
 *
 * Al instrumentarlo (28/07, 15 pulsaciones seguidas, todas iguales) quedo
 * claro: el host SI respondia, en el mismo segundo, y devolvia el
 * ACTION_NAVIGATE a la propia LMB10. Causa: el manifest declaraba la categoria
 * NAVIGATION, asi que para Android Auto la app de navegacion del coche eramos
 * nosotros y el host nos resolvia el intent a nosotros mismos.
 *
 * Corregido pasando la categoria a POI. Ojo: CHARGING y PARKING estan
 * obsoletas y Play rechaza el bundle si se usan.
 */
class ChargerDetailScreen(
    carContext: CarContext,
    private val c: CarCharger
) : Screen(carContext) {

    // Via 1: el host del coche. URI "geo:lat,lon" = ir a un punto. Antes se
    // mandaba "geo:0,0?q=..." que es la forma de BUSQUEDA, no la de destino.
    // Con la categoria POI en el manifest el host resuelve este intent a Google
    // Maps y lo abre en la pantalla del coche, sin tocar el movil ni depender
    // de que este desbloqueado. Es la via buena.
    // Si algun dia vuelve a no abrir nada, lo PRIMERO que hay que mirar es si
    // la categoria del manifest ha vuelto a ser NAVIGATION, y lo segundo el
    // log de Session.onNewIntent().
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
            // es startCarApp(ACTION_NAVIGATE), que funciona desde el 28/07.
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
            try {
                return construirBloqueado()
            } catch (t: Throwable) {
                CarLog.log(carContext, "NAV", "locked EXCEPCION " + t.javaClass.simpleName)
                return Row.Builder().setTitle("Desbloquea el movil y reintenta").build()
                    .let { row ->
                        ListTemplate.Builder()
                            .setSingleList(ItemList.Builder().addItem(row).build())
                            .setTitle("Movil bloqueado")
                            .setHeaderAction(Action.BACK)
                            .build()
                    }
            }
        }

        private fun construirBloqueado(): Template {
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
            try {
                return construirEnviado()
            } catch (t: Throwable) {
                CarLog.log(carContext, "NAV", "enviado EXCEPCION " + t.javaClass.simpleName)
                return ListTemplate.Builder()
                    .setSingleList(ItemList.Builder()
                        .addItem(Row.Builder()
                            .setTitle("Ruta enviada. Abre Maps en el coche para verla.")
                            .build())
                        .build())
                    .setTitle("Ruta enviada")
                    .setHeaderAction(Action.BACK)
                    .build()
            }
        }

        private fun construirEnviado(): Template {
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
        try {
            return construir()
        } catch (t: Throwable) {
            // PaneTemplate no es valido en conduccion para apps POI: el host
            // (o la propia libreria) la rechaza y mata la sesion con el
            // generico "error no esperado" (visto en la unidad real). Se
            // deja constancia y se sirve una lista simple, valida en marcha.
            CarLog.log(carContext, "NAV", "detalle EXCEPCION " +
                t.javaClass.simpleName + ": " + t.message)
            return construirDegradado()
        }
    }

    /// Version conservadora del detalle: lista simple con la misma info y
    /// solo la navegacion por el host (valida en conduccion). Sin pane.
    private fun construirDegradado(): Template {
        return ListTemplate.Builder()
            .setSingleList(ItemList.Builder()
                .addItem(Row.Builder()
                    .setTitle(c.name)
                    .addText("Sin detalle disponible ahora")
                    .build())
                .build())
            .setTitle("Cargador")
            .setHeaderAction(Action.BACK)
            .build()
    }

    private fun construir(): Template {
        val list = ItemList.Builder()
        val km = String.format("%.1f km", c.distM / 1000f)
        list.addItem(Row.Builder().setTitle("Distancia").addText(km).build())
        if (c.info.isNotEmpty()) {
            list.addItem(Row.Builder().setTitle("Operador").addText(c.info).build())
        }
        if (c.kw != null) {
            list.addItem(Row.Builder()
                .setTitle("Potencia")
                .addText(String.format("%.0f kW", c.kw))
                .build())
        }
        if (c.plazas != null) {
            list.addItem(Row.Builder()
                .setTitle("Plazas")
                .addText(c.plazas.toString())
                .build())
        }
        // v3.60.196: la navegacion va en FILAS pulsables, no en la barra de
        // acciones. El host del B10 rechaza acciones de titulo propio
        // ("Action list exceeded max number of 0 actions with custom
        // titles", carlog 27/09) y las filas son la interaccion que la
        // categoria POI permite siempre, parado o en marcha.
        list.addItem(Row.Builder()
            .setTitle("Navegar: Maps del coche")
            .setOnClickListener { viaHost() }
            .build())
        list.addItem(Row.Builder()
            .setTitle("Enviar a Maps del movil")
            .setOnClickListener { viaPhone() }
            .build())
        return ListTemplate.Builder()
            .setSingleList(list.build())
            .setTitle(c.name)
            .setHeaderAction(Action.BACK)
            .build()
    }}
