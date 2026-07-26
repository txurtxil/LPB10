package com.txurtxil.lpb10

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import androidx.car.app.CarContext
import androidx.car.app.CarToast
import androidx.car.app.Screen
import androidx.car.app.model.Action
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
        val nav = Uri.parse("google.navigation:q=" + c.lat + "," + c.lon)
        try {
            CarLog.log(carContext, "NAV", "MOVIL intento " + nav)
            val i = Intent(Intent.ACTION_VIEW, nav)
            i.setPackage("com.google.android.apps.maps")
            i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            carContext.startActivity(i)
            CarLog.log(carContext, "NAV", "MOVIL lanzado con Maps")
        } catch (e: ActivityNotFoundException) {
            CarLog.log(carContext, "NAV", "MOVIL sin Maps, reintento generico")
            try {
                val g = Intent(Intent.ACTION_VIEW,
                    Uri.parse("geo:" + c.lat + "," + c.lon + "?q=" + c.lat + "," + c.lon))
                g.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                carContext.startActivity(g)
                CarLog.log(carContext, "NAV", "MOVIL lanzado generico")
            } catch (e2: Exception) {
                CarLog.log(carContext, "NAV", "MOVIL fallo: " + e2.javaClass.simpleName + " " + e2.message)
                CarToast.makeText(carContext, "No hay app de mapas", CarToast.LENGTH_LONG).show()
            }
        } catch (e: Exception) {
            CarLog.log(carContext, "NAV", "MOVIL fallo: " + e.javaClass.simpleName + " " + e.message)
            CarToast.makeText(carContext, "Android bloqueo la apertura", CarToast.LENGTH_LONG).show()
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
            Action.Builder().setTitle("Navegar").setOnClickListener { viaHost() }.build()
        )
        pane.addAction(
            Action.Builder().setTitle("En el movil").setOnClickListener { viaPhone() }.build()
        )
        return PaneTemplate.Builder(pane.build())
            .setTitle(c.name)
            .setHeaderAction(Action.BACK)
            .build()
    }
}
