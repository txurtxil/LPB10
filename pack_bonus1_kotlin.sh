#!/usr/bin/env bash
set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
K=android/app/src/main/kotlin/com/txurtxil/lpb10
cp $K/CarMainScreen.kt backups_widget/CarMainScreen.kt.bak_$TS
echo "[i] Backup en *.bak_$TS"

# ============ 1. QuickActionsScreen.kt (usa CarBridge.invoke generico) ============
cat > $K/QuickActionsScreen.kt <<'KEOF'
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
        QA("lock", "Cerrar", R.drawable.ic_car_battery),
        QA("unlock", "Abrir", R.drawable.ic_car_battery),
        QA("heat", "Calor", R.drawable.ic_car_battery),
        QA("cool", "Frio", R.drawable.ic_car_battery),
        QA("defrost", "Desempanar", R.drawable.ic_car_battery),
        QA("find", "Buscar coche", R.drawable.ic_car_chargers),
        QA("trunk", "Maletero", R.drawable.ic_car_battery),
        QA("sentry_on", "Centinela ON", R.drawable.ic_car_battery),
        QA("preheat", "Precalentar", R.drawable.ic_car_battery)
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
KEOF
echo "[ok] QuickActionsScreen.kt creado"

# ============ 2. Enganchar fila en el hub (nombres reales: list, icon) ============
python3 - <<'PYEOF'
import io, sys
p = "android/app/src/main/kotlin/com/txurtxil/lpb10/CarMainScreen.kt"
s = io.open(p, encoding='utf-8').read()

if "QuickActionsScreen(carContext)" in s:
    sys.exit("[skip] ya enganchado")

# Insertar la fila "Acciones rapidas" justo despues del bloque de Rutinas.
# Ancla: el bloque completo de la Row de Rutinas.
anchor = '''        list.addItem(
            Row.Builder()
                .setTitle("Rutinas")
                .addText("Clima, cerrar y mas")
                .setImage(icon(R.drawable.ic_car_routine))
                .setBrowsable(true)
                .setOnClickListener { screenManager.push(RoutinesScreen(carContext)) }
                .build()
        )'''
if s.count(anchor) != 1:
    sys.exit("ABORT: ancla fila Rutinas x%d" % s.count(anchor))

newrow = anchor + '''
        list.addItem(
            Row.Builder()
                .setTitle("Acciones rapidas")
                .addText("Cerrar, clima, centinela y mas")
                .setImage(icon(R.drawable.ic_car_routine))
                .setBrowsable(true)
                .setOnClickListener { screenManager.push(QuickActionsScreen(carContext)) }
                .build()
        )'''
s = s.replace(anchor, newrow, 1)
io.open(p, 'w', encoding='utf-8').write(s)
print("[ok] CarMainScreen: fila Acciones rapidas añadida")
PYEOF

echo "[i] Verificacion:"
echo -n "  QuickActionsScreen existe: "; ls $K/QuickActionsScreen.kt >/dev/null 2>&1 && echo OK
echo -n "  enganchado en hub (1): "; grep -c "QuickActionsScreen(carContext)" $K/CarMainScreen.kt
echo -n "  usa CarBridge.invoke (1): "; grep -c "CarBridge.invoke" $K/QuickActionsScreen.kt
