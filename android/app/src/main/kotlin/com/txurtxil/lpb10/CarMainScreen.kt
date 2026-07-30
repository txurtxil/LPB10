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

        list.addItem(
            Row.Builder()
                .setTitle("Rutinas")
                .addText("Clima, cerrar y mas")
                .setImage(icon(R.drawable.ic_car_routine))
                .setBrowsable(true)
                .setOnClickListener { screenManager.push(RoutinesScreen(carContext)) }
                .build()
        )
        list.addItem(
            Row.Builder()
                .setTitle("Acciones rapidas")
                .addText("Cerrar, clima, centinela y mas")
                .setImage(icon(R.drawable.ic_car_routine))
                .setBrowsable(true)
                .setOnClickListener { screenManager.push(QuickActionsScreen(carContext)) }
                .build()
        )

        list.addItem(
            Row.Builder()
                .setTitle("Consumo")
                .addText("Gasto real del ciclo actual")
                .setImage(icon(R.drawable.ic_car_routine))
                .setBrowsable(true)
                .setOnClickListener { screenManager.push(ConsumoChartScreen(carContext)) }
                .build()
        )

        list.addItem(
            Row.Builder()
                .setTitle("Cargadores cerca")
                .addText("Puntos de carga en 5 km")
                .setImage(icon(R.drawable.ic_car_charger))
                .setBrowsable(true)
                .setOnClickListener { screenManager.push(ChargersScreen(carContext)) }
                .build()
        )

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
