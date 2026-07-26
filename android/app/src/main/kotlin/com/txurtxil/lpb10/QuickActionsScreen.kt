package com.txurtxil.lpb10

import android.os.Handler
import android.os.Looper
import androidx.car.app.CarContext
import androidx.car.app.CarToast
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.CarIcon
import androidx.car.app.model.GridItem
import androidx.car.app.model.GridTemplate
import androidx.car.app.model.ItemList
import androidx.car.app.model.Template
import androidx.core.graphics.drawable.IconCompat

class QuickActionsScreen(carContext: CarContext) : Screen(carContext) {

    private data class QA(val action: String, val label: String, val icon: Int)

    // Acciones utiles en el coche. Iconos: reutilizamos los vectoriales que hay.
    private val actions = listOf(
        QA("lock", "Cerrar", R.drawable.ic_qa_lock),
        QA("unlock", "Abrir", R.drawable.ic_qa_unlock),
        QA("heat", "Calor", R.drawable.ic_qa_heat),
        QA("cool", "Frio", R.drawable.ic_qa_cool),
        QA("defrost", "Desempanar", R.drawable.ic_qa_defrost),
        QA("find", "Buscar coche", R.drawable.ic_qa_find),
        QA("trunk", "Maletero", R.drawable.ic_qa_trunk),
        QA("sentry_on", "Centinela ON", R.drawable.ic_qa_sentry),
        QA("preheat", "Precalentar", R.drawable.ic_qa_preheat),
        QA("trunk_close", "Cerrar maletero", R.drawable.ic_qa_trunk_close),
        QA("wheel_heat", "Volante calef.", R.drawable.ic_qa_wheel),
        QA("charger_unlock", "Liberar cargador", R.drawable.ic_qa_charger)
    )

    private fun icon(res: Int): CarIcon =
        CarIcon.Builder(IconCompat.createWithResource(carContext, res)).build()

    override fun onGetTemplate(): Template {
        val list = ItemList.Builder()
        for (qa in actions) {
            list.addItem(
                GridItem.Builder()
                    .setTitle(qa.label)
                    .setImage(icon(qa.icon))
                    .setOnClickListener { fire(qa) }
                    .build()
            )
        }
        return GridTemplate.Builder()
            .setSingleList(list.build())
            .setTitle("Acciones rapidas")
            .setHeaderAction(Action.BACK)
            .build()
    }

    private fun fire(qa: QA) {
        CarToast.makeText(carContext, "Enviando: " + qa.label, CarToast.LENGTH_SHORT).show()
        CarLog.log(carContext, "QUICK", "accion " + qa.action)
        CarBridge.invoke("quickAction", mapOf("action" to qa.action)) { ok ->
            Handler(Looper.getMainLooper()).post {
                val msg = if (ok) qa.label + ": hecho" else qa.label + ": fallo"
                CarToast.makeText(carContext, msg, CarToast.LENGTH_LONG).show()
            }
        }
    }
}
