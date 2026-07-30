set -euo pipefail
cd ~/LP10
TS=$(date +%Y%m%d_%H%M%S)
K=android/app/src/main/kotlin/com/txurtxil/lpb10
cp "$K/ConsumoChartScreen.kt" "backups_widget/ConsumoChartScreen.kt.bak_$TS"
echo "Backup: backups_widget/ConsumoChartScreen.kt.bak_$TS"

python3 - << 'PYEOF'
import sys
p = 'android/app/src/main/kotlin/com/txurtxil/lpb10/ConsumoChartScreen.kt'
s = open(p, encoding='utf-8').read()

i = s.find('    private fun dibuja(')
if i < 0:
    print("ABORTA: no encuentro dibuja()"); sys.exit(1)
j = s.rfind('}')

nuevo = '''    private fun dibuja(dias: List<Pair<String, Float>>, avg: Float?, es: Boolean): Bitmap {
        val n = 480
        val bmp = Bitmap.createBitmap(n, n, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val p = Paint(Paint.ANTI_ALIAS_FLAG)

        val izq = 22f
        val der = n - 22f
        val arriba = 74f
        val abajo = n - 58f
        val alto = abajo - arriba

        val maxDato = dias.maxOf { it.second }
        val techo = (if (avg != null) maxOf(maxDato, avg) else maxDato) * 1.18f

        // La media va en la LEYENDA, no rotulada sobre su linea. En el coche,
        // el 30/07, las barras que valian casi lo mismo que la media pintaban
        // su etiqueta justo encima del rotulo y se solapaban los tres numeros.
        p.color = Color.WHITE
        p.textAlign = Paint.Align.LEFT
        p.textSize = 28f
        p.isFakeBoldText = true
        c.drawText("kWh/100 km", izq, 34f, p)
        p.isFakeBoldText = false
        if (avg != null && avg > 0f) {
            p.color = Color.parseColor("#CCFFFFFF")
            p.textSize = 24f
            c.drawText((if (es) "media " else "avg ") + fmt(avg), izq, 62f, p)
        }

        p.color = Color.parseColor("#44FFFFFF")
        p.strokeWidth = 2f
        c.drawLine(izq, abajo, der, abajo, p)

        val ancho = (der - izq) / dias.size
        val barra = ancho * 0.58f

        for (i in dias.indices) {
            val (etiqueta, valor) = dias[i]
            val cx = izq + ancho * i + ancho / 2f
            val h = (valor / techo) * alto
            val color = if (avg != null && valor > avg)
                Color.parseColor("#E9A23B") else Color.parseColor("#2A9D8F")

            p.style = Paint.Style.FILL
            p.color = color
            c.drawRoundRect(
                RectF(cx - barra / 2f, abajo - h, cx + barra / 2f, abajo), 7f, 7f, p)

            p.color = Color.WHITE
            p.textAlign = Paint.Align.CENTER
            p.textSize = 23f
            c.drawText(fmt(valor), cx, abajo - h - 10f, p)

            // Solo el dia del mes: "24/07" siete veces no cabe a este tamano y
            // las fechas acababan tocandose.
            p.color = Color.parseColor("#AAFFFFFF")
            p.textSize = 24f
            c.drawText(etiqueta.substringBefore("/"), cx, abajo + 30f, p)
        }

        // Linea de media sin rotulo, encima de las barras.
        if (avg != null && avg > 0f) {
            val y = abajo - (avg / techo) * alto
            p.style = Paint.Style.STROKE
            p.strokeWidth = 3f
            p.color = Color.parseColor("#DDFFFFFF")
            var x = izq
            while (x < der) {
                c.drawLine(x, y, minOf(x + 12f, der), y, p)
                x += 22f
            }
            p.style = Paint.Style.FILL
        }
        return bmp
    }
}'''
s = s[:i] + nuevo
open(p, 'w', encoding='utf-8').write(s)
d = (s.count('('), s.count(')'), s.count('{'), s.count('}'))
print("  parentesis %d/%d   llaves %d/%d" % d)
if d[0] != d[1] or d[2] != d[3]:
    print("ABORTA: descuadre"); sys.exit(1)
print("OK")
PYEOF

echo "--- verificacion ---"
echo -n "leyenda de media: "; grep -c 'media ' "$K/ConsumoChartScreen.kt"
echo -n "substringBefore: "; grep -c 'substringBefore' "$K/ConsumoChartScreen.kt"
echo
echo "=== DATOS QUE NECESITO PARA LAS RUEDAS ==="
echo "--- campos de presion en el motor ---"
grep -n 'TireKpa\|tirePressureAlerts' lib/leapmotor_engine.dart | head -20
echo "--- la linea que escribe tireAlerts y su entorno ---"
sed -n '1378,1392p' lib/main.dart | cat -n
echo
echo "--- compilando ---"
flutter build apk --release 2>&1 | tail -5
