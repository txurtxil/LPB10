set -euo pipefail
cd ~/LP10
K=android/app/src/main/kotlin/com/txurtxil/lpb10

python3 - << 'PYEOF'
import glob, sys
def delta(p):
    s = open(p, encoding='utf-8').read()
    return (s.count('(')-s.count(')'), s.count('{')-s.count('}'), s.count('[')-s.count(']'))
bak = sorted(glob.glob('backups_widget/main.dart.bak_20260730_183408'))
if not bak:
    print("ABORTA: no encuentro el backup de esta tanda"); sys.exit(1)
a, b = delta(bak[0]), delta('lib/main.dart')
print("  backup %s   actual %s" % (a, b))
if a != b:
    print("ABORTA: el parche de dart SI descuadro"); sys.exit(1)
s = open('lib/main.dart', encoding='utf-8').read()
if s.count("'tireKpa'") != 1 or s.count("'tireState'") != 1:
    print("ABORTA: tireKpa/tireState no aparecen exactamente una vez"); sys.exit(1)
print("OK: main.dart correcto, balance identico al original")
PYEOF

cp "$K/TiresScreen.kt" "backups_widget/TiresScreen.kt.bak_$(date +%Y%m%d_%H%M%S)"

cat > "$K/TiresScreen.kt" << 'KTEOF'
package com.txurtxil.lpb10

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.CarIcon
import androidx.car.app.model.Pane
import androidx.car.app.model.PaneTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import androidx.core.graphics.drawable.IconCompat
import es.antonborri.home_widget.HomeWidgetPlugin

/**
 * Ruedas, con silueta del coche y la presion de cada una en su esquina.
 *
 * La version anterior pintaba una barra de bloques que NO media nada: era
 * binaria, llena si la rueda estaba bien y a medias si estaba en alerta,
 * porque solo llegaba tireAlerts con los nombres de las ruedas afectadas.
 * Ahora viajan tambien tireKpa y tireState desde Dart.
 *
 * Lienzo cuadrado: la ranura de imagen del Pane recorta los laterales.
 */
class TiresScreen(carContext: CarContext) : Screen(carContext) {

    override fun onGetTemplate(): Template {
        val p = HomeWidgetPlugin.getData(carContext)
        val es = (p.getString("lang", "es") ?: "es").startsWith("es")

        val kpa = (p.getString("tireKpa", "") ?: "").split("|")
        val estado = (p.getString("tireState", "") ?: "").split("|")
        val alertsRaw = p.getString("tireAlerts", "") ?: ""
        val alerts = alertsRaw.split("|").filter { it.isNotEmpty() }

        val valores = (0..3).map { kpa.getOrNull(it)?.toIntOrNull() }
        val malas = (0..3).map { (estado.getOrNull(it)?.toIntOrNull() ?: 0) != 0 }
        val hayDatos = valores.any { it != null }

        val pane = Pane.Builder()

        if (hayDatos) {
            try {
                pane.setImage(
                    CarIcon.Builder(IconCompat.createWithBitmap(dibuja(valores, malas))).build())
                CarLog.log(carContext, "RUE", "bitmap ok, kpa=" + kpa.joinToString(","))
            } catch (e: Exception) {
                CarLog.log(carContext, "RUE", "bitmap fallo: " + e)
            }
        }

        val resumen = when {
            alerts.isNotEmpty() -> (if (es) "Revisa: " else "Check: ") + alerts.joinToString(", ")
            hayDatos -> if (es) "Las cuatro ruedas correctas" else "All four tyres OK"
            else -> if (es) "Sin lectura de presiones" else "No pressure readings"
        }
        pane.addRow(
            Row.Builder()
                .setTitle(if (es) "Estado" else "Status")
                .addText(resumen)
                .build()
        )

        if (hayDatos) {
            val leidas = valores.filterNotNull()
            val dif = if (leidas.size >= 2) leidas.max() - leidas.min() else 0
            pane.addRow(
                Row.Builder()
                    .setTitle(if (es) "Diferencia entre ruedas" else "Spread between tyres")
                    .addText(dif.toString() + " kPa  ·  " + fmtBar(dif) + " bar")
                    .build()
            )
        } else {
            pane.addRow(
                Row.Builder()
                    .setTitle(if (es) "Sin datos" else "No data")
                    .addText(if (es)
                        "El coche no esta reportando presiones ahora mismo."
                        else "The car is not reporting pressures right now.")
                    .build()
            )
        }

        return PaneTemplate.Builder(pane.build())
            .setTitle(if (es) "Ruedas" else "Tyres")
            .setHeaderAction(Action.BACK)
            .build()
    }

    private fun fmtBar(kpa: Int): String =
        String.format("%.2f", kpa / 100f).replace('.', ',')

    private fun dibuja(v: List<Int?>, malas: List<Boolean>): Bitmap {
        val n = 480
        val bmp = Bitmap.createBitmap(n, n, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val p = Paint(Paint.ANTI_ALIAS_FLAG)

        p.style = Paint.Style.STROKE
        p.strokeWidth = 5f
        p.color = Color.parseColor("#55FFFFFF")
        c.drawRoundRect(RectF(160f, 78f, 320f, 402f), 58f, 58f, p)
        c.drawLine(240f, 150f, 240f, 330f, p)

        val posX = listOf(120f, 360f, 120f, 360f)
        val posY = listOf(150f, 150f, 330f, 330f)

        for (i in 0..3) {
            val lectura = v.getOrNull(i)
            val mala = malas.getOrNull(i) ?: false
            val color = when {
                lectura == null -> Color.parseColor("#66FFFFFF")
                mala -> Color.parseColor("#E63946")
                else -> Color.parseColor("#2A9D8F")
            }

            p.style = Paint.Style.FILL
            p.color = color
            c.drawRoundRect(
                RectF(posX[i] - 26f, posY[i] - 46f, posX[i] + 26f, posY[i] + 46f), 14f, 14f, p)

            p.color = Color.WHITE
            p.textAlign = Paint.Align.CENTER
            p.isFakeBoldText = true
            p.textSize = 34f
            c.drawText(if (lectura == null) "--" else fmtBar(lectura), posX[i], posY[i] + 82f, p)
            p.isFakeBoldText = false
            p.textSize = 20f
            p.color = Color.parseColor("#99FFFFFF")
            c.drawText("bar", posX[i], posY[i] + 106f, p)
        }
        return bmp
    }
}
KTEOF
echo "TiresScreen.kt reescrita"

echo "--- verificaciones ---"
echo -n "tireKpa en dart: "; grep -c "'tireKpa'" lib/main.dart
echo -n "drawRoundRect en ruedas: "; grep -c 'drawRoundRect' "$K/TiresScreen.kt"
echo
flutter analyze 2>&1 | grep '• lib/' | grep error || echo "analyze: sin errores"
echo "--- compilando ---"
flutter build apk --release 2>&1 | tail -5
