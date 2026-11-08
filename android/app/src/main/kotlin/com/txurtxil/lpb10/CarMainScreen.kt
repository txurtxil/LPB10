package com.txurtxil.lpb10
import com.txurtxil.lpb10.BuildConfig

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.CarIcon
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import androidx.core.graphics.drawable.IconCompat
import es.antonborri.home_widget.HomeWidgetPlugin

class CarMainScreen(carContext: CarContext) : Screen(carContext) {

    private fun icon(res: Int): CarIcon =
        CarIcon.Builder(IconCompat.createWithResource(carContext, res)).build()

    override fun onGetTemplate(): Template {
        val prefs = HomeWidgetPlugin.getData(carContext)
        val soc = prefs.getString("soc", null)
        val range = prefs.getString("range", null)
        val realRange = prefs.getString("realRange", null)
        val locked = prefs.getString("locked", null)
        val charging = prefs.getString("charging", null)

        val socText = if (!soc.isNullOrEmpty()) soc + " %" else "-- %"
        val rangeText = when {
            !range.isNullOrEmpty() && !realRange.isNullOrEmpty() ->
                range + " km / real ~" + realRange + " km"
            !range.isNullOrEmpty() -> range + " km"
            else -> "-- km"
        }
        val estado = when (locked) {
            "1" -> "Cerrado"; "0" -> "Abierto"; else -> "Desconocido"
        }
        val estadoLinea = if (charging == "1") estado + " / Cargando" else estado

        val list = ItemList.Builder()

        list.addItem(
            Row.Builder()
                .setTitle("Conduccion")
                .addText("Velocidad, hora y autonomia en grande")
                .setBrowsable(true)
                .setOnClickListener { screenManager.push(DriveScreen(carContext)) }
                .build()
        )

        list.addItem(
            Row.Builder()
                .setTitle("Bateria  " + socText)
                .addText(rangeText + "  ·  " + estadoLinea)
                .setImage(icon(R.drawable.ic_car_battery))
                .setBrowsable(true)
                .setOnClickListener { screenManager.push(BatteryScreen(carContext)) }
                .build()
        )

        list.addItem(
            Row.Builder()
                .setTitle("Ruedas")
                .addText("Estado de las 4 ruedas")
                .setImage(icon(R.drawable.ic_car_tire))
                .setBrowsable(true)
                .setOnClickListener { screenManager.push(TiresScreen(carContext)) }
                .build()
        )

        // v-next (2026-11-07, issue #15): esta variante NO va por Play, asi
        // que el criterio PF-1 ya no aplica: re-enlazamos las pantallas.
        list.addItem(
            Row.Builder()
                .setTitle("Consumo")
                .addText("Media del trayecto y grafica")
                .setBrowsable(true)
                .setOnClickListener { screenManager.push(ConsumoScreen(carContext)) }
                .build()
        )

        list.addItem(
            Row.Builder()
                .setTitle("Acciones rapidas")
                .addText("Bloquear, clima, maletero...")
                .setBrowsable(true)
                .setOnClickListener { screenManager.push(QuickActionsScreen(carContext)) }
                .build()
        )

        list.addItem(
            Row.Builder()
                .setTitle("Rutinas")
                .addText("Ejecutar rutinas guardadas")
                .setBrowsable(true)
                .setOnClickListener { screenManager.push(RoutinesScreen(carContext)) }
                .build()
        )

        // "Cargadores cerca" FUERA del hub del coche (owner 7-nov): no
        // merece la pena en Auto; sigue en la app del movil. ChargersScreen
        // queda en el codigo por si se reactiva.

        list.addItem(
            Row.Builder()
                .setTitle("LMB10 · SurferRule")
                .addText("github.com/txurtxil/LPB10")
                .build()
        )

        return ListTemplate.Builder()
            .setSingleList(list.build())
            .setTitle("LMB10 v" + BuildConfig.VERSION_NAME)
            .setHeaderAction(Action.APP_ICON)
            .build()
    }
}
