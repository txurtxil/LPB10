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
import androidx.car.app.model.MessageTemplate
import androidx.car.app.model.Template
import androidx.core.graphics.drawable.IconCompat

class QuickActionsScreen(carContext: CarContext) : Screen(carContext) {

    private data class QA(
        val action: String,
        val label: String,
        val icon: Int,
        val confirm: Boolean = false
    )

    // Acciones utiles en el coche. Iconos: reutilizamos los vectoriales que hay.
    private val actions = listOf(
        QA("lock", "Cerrar", R.drawable.ic_qa_lock),
        QA("unlock", "Abrir", R.drawable.ic_qa_unlock, confirm = true),
        QA("heat", "Calor", R.drawable.ic_qa_heat),
        QA("cool", "Frio", R.drawable.ic_qa_cool),
        QA("defrost", "Desempanar", R.drawable.ic_qa_defrost),
        QA("find", "Buscar coche", R.drawable.ic_qa_find),
        QA("trunk", "Maletero", R.drawable.ic_qa_trunk, confirm = true),
        QA("sentry_on", "Centinela ON", R.drawable.ic_qa_sentry),
        QA("preheat", "Precalentar", R.drawable.ic_qa_preheat),
        QA("trunk_close", "Cerrar maletero", R.drawable.ic_qa_trunk_close, confirm = true),
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

    // Las acciones con confirm = true pasan por una pantalla intermedia.
    // Motivo: "Abrir" esta pegada a "Cerrar" en la parrilla y fire() enviaba el
    // comando al instante, sin red de seguridad. Un dedo que resbala en un
    // bache y el coche queda desbloqueado en marcha. Igual con el maletero.
    private fun fire(qa: QA) {
        if (qa.confirm) {
            screenManager.push(ConfirmScreen(carContext, qa.label) { send(qa) })
        } else {
            send(qa)
        }
    }

    private fun send(qa: QA) {
        CarToast.makeText(carContext, "Enviando: " + qa.label, CarToast.LENGTH_SHORT).show()
        CarLog.log(carContext, "QUICK", "accion " + qa.action)
        CarBridge.invoke("quickAction", mapOf("action" to qa.action)) { ok ->
            Handler(Looper.getMainLooper()).post {
                val msg = if (ok) qa.label + ": hecho" else qa.label + ": fallo"
                CarToast.makeText(carContext, msg, CarToast.LENGTH_LONG).show()
            }
        }
    }

    private class ConfirmScreen(
        carContext: CarContext,
        private val label: String,
        private val onOk: () -> Unit
    ) : Screen(carContext) {
        override fun onGetTemplate(): Template {
            return MessageTemplate.Builder(label + "?")
                .setTitle("Confirmar accion")
                .setHeaderAction(Action.BACK)
                .addAction(
                    Action.Builder()
                        .setTitle("Confirmar")
                        .setOnClickListener {
                            CarLog.log(carContext, "QUICK", "confirmado " + label)
                            screenManager.pop()
                            onOk()
                        }
                        .build()
                )
                .addAction(
                    Action.Builder()
                        .setTitle("Cancelar")
                        .setOnClickListener {
                            CarLog.log(carContext, "QUICK", "cancelado " + label)
                            screenManager.pop()
                        }
                        .build()
                )
                .build()
        }
    }
}
