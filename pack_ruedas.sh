set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
K=android/app/src/main/kotlin/com/txurtxil/lpb10
cp lib/main.dart "backups_widget/main.dart.bak_$TS"
cp "$K/TiresScreen.kt" "backups_widget/TiresScreen.kt.bak_$TS"
echo "Backups con sufijo .bak_$TS"

python3 - << 'PYEOF'
import sys
p = 'lib/main.dart'
s = open(p, encoding='utf-8').read()
antes = (s.count('('), s.count(')'), s.count('{'), s.count('}'))

old = "  await HomeWidget.saveWidgetData<String>('tireAlerts', s.tirePressureAlerts.join('|'));"
if s.count(old) != 1:
    print("ABORTA: ancla tireAlerts aparece %d veces" % s.count(old)); sys.exit(1)

nuevo = old + '''
  // Presiones en kPa para la silueta de Android Auto. Hasta ahora solo viajaba
  // tireAlerts (nombres de ruedas en alerta), asi que la pantalla del coche no
  // tenia los numeros y pintaba una barra que en realidad no media nada.
  // Orden fijo: delantera izq, delantera der, trasera izq, trasera der.
  // Vacio = sin lectura; NO se manda 0, que se confundiria con una presion.
  await HomeWidget.saveWidgetData<String>(
      'tireKpa',
      [s.leftFrontTireKpa, s.rightFrontTireKpa, s.leftRearTireKpa, s.rightRearTireKpa]
          .map((v) => v?.toString() ?? '')
          .join('|'));
  await HomeWidget.saveWidgetData<String>(
      'tireState',
      ['leftFrontTirePressureState', 'rightFrontTirePressureState',
       'leftRearTirePressureState', 'rightRearTirePressureState']
          .map((k) => s.raw[k]?.toString() ?? '')
          .join('|'));'''
s = s.replace(old, nuevo)
open(p, 'w', encoding='utf-8').write(s)
d = (s.count('('), s.count(')'), s.count('{'), s.count('}'))
print("  main.dart parentesis %d/%d -> %d/%d" % (antes[0], antes[1], d[0], d[1]))
if d[0] != d[1] or d[2] != d[3]:
    print("ABORTA: descuadre en main.dart"); sys.exit(1)
print("OK dart")
PYEOF

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
 * Desde la v3.60.32 viajan tambien tireKpa y tireState.
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

        // Carroceria esquematica, vista cenital
        p.style = Paint.Style.STROKE
        p.strokeWidth = 5f
        p.color = Color.parseColor("#55FFFFFF")
        c.drawRoundRect(RectF(160f, 78f, 320f, 402f), 58f, 58f, p)
        c.drawLine(240f, 150f, 240f, 330f, p)

        // Ruedas: 0 del.izq  1 del.der  2 tras.izq  3 tras.der
        val posX = listOf(120f, 360f, 120f, 360f)
        val posY = listOf(150f, 150f, 330f, 330f)

        for (i in 0..3) {
            val val_ = v.getOrNull(i)
            val mala = malas.getOrNull(i) ?: false
            val color = when {
                val_ == null -> Color.parseColor("#66FFFFFF")
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
            val txt = if (val_ == null) "--" else fmtBar(val_)
            c.drawText(txt, posX[i], posY[i] + 82f, p)
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
echo -n "tireState en dart: "; grep -c "'tireState'" lib/main.dart
echo
echo "--- analyze ---"
flutter analyze 2>&1 | grep '• lib/' | grep error || echo "(sin errores)"
echo "--- compilando ---"
flutter build apk --release 2>&1 | tail -5
