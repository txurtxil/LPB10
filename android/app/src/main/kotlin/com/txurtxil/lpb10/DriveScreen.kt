package com.txurtxil.lpb10

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.location.LocationListener
import android.location.LocationManager
import android.os.Handler
import android.os.Looper
import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.CarIcon
import androidx.car.app.model.Pane
import androidx.car.app.model.PaneTemplate
import androidx.car.app.model.Tab
import androidx.car.app.model.TabContents
import androidx.car.app.model.TabTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.Template
import androidx.core.graphics.drawable.IconCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.cos
import kotlin.math.sin

// Cuadro de conduccion (issue #18, idea de @MF_Pau): velocimetro moderno
// dibujado en bitmap (Canvas -> CarIcon, mismo truco que ConsumoChartScreen)
// + velocidad por GPS del movil (1 s, sin nube; respaldo: senal del coche
// via prefs). El resto de datos sigue viniendo de la nube (refresh ~24 s).
class DriveScreen(carContext: CarContext) : Screen(carContext) {

    private val handler = Handler(Looper.getMainLooper())
    private var ticks = 0
    private var phoneSpeedKmh: Float? = null
    private var lastFixMs: Long = 0

    private val refresher = object : Runnable {
        override fun run() {
            ticks++
            if (ticks % 6 == 1) CarBridge.invoke("refresh", null) { }
            invalidate()
            handler.postDelayed(this, 4000)
        }
    }

    private val locListener = LocationListener { loc ->
        if (loc.hasSpeed()) {
            phoneSpeedKmh = loc.speed * 3.6f
            lastFixMs = System.currentTimeMillis()
        }
    }

    init {
        val lm = carContext.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        if (carContext.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED) {
            try {
                lm.requestLocationUpdates(LocationManager.GPS_PROVIDER, 1000L, 0f, locListener)
            } catch (_: SecurityException) { }
        }
        lifecycle.addObserver(LifecycleEventObserver { _, ev ->
            if (ev == Lifecycle.Event.ON_DESTROY) {
                lm.removeUpdates(locListener)
                handler.removeCallbacks(refresher)
            }
        })
        CarBridge.invoke("refresh", null) { }
        handler.post(refresher)
    }

    private fun d(name: String): String =
        HomeWidgetPlugin.getData(carContext).getString(name, "") ?: ""

    override fun onGetTemplate(): Template {
        val speed = currentSpeed()
        val kwS = d("kw")
        val range = d("range")
        val soc = d("soc")
        val hora = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date())
        val kwh100 = instantConsumption(speed, kwS)

        val gauge = dibujaGauge(speed, kwS, soc, range, kwh100, hora)

        // GridTemplate: el gauge como GridItem de imagen GRANDE. La
        // plantilla de lista lo achataba a miniatura; en grid ocupa la
        // celda completa. La info de texto va DENTRO del bitmap (fila
        // SoC/autonomia/consumo/hora dibujada en el propio gauge).
        // PaneTemplate + pane.setImage: la ranura de imagen del PANE se
        // ve GRANDE en el host (como el dibujo de las ruedas de
        // TiresScreen); las imagenes de fila/grid salen diminutas.
        // Solo la fila API: las demas filas estrechan la zona de imagen
        // del pane; con una sola el gauge ocupa mas.
        val pane = Pane.Builder()
            .setImage(CarIcon.Builder(IconCompat.createWithBitmap(gauge)).build())
            .addRow(Row.Builder().setTitle("API " + carContext.carAppApiLevel).addText("beta 3.60.268-beta.3").build())
            .build()
        return PaneTemplate.Builder(pane)
            .setTitle("LMB10 - Conduccion")
            .setHeaderAction(Action.BACK)
            .build()
    }

    private fun row(t: String, b: String): Row =
        Row.Builder().setTitle(t).addText(b).build()

    private fun currentSpeed(): Float {
        val gps = phoneSpeedKmh?.takeIf { System.currentTimeMillis() - lastFixMs < 6000 }
        if (gps != null) return gps
        return d("speed").toFloatOrNull() ?: 0f
    }

    private fun instantConsumption(speedKmh: Float, kwS: String): String {
        val kw = kwS.toFloatOrNull() ?: return "--"
        if (speedKmh < 5f) return "--"
        return "%.1f".format(kw / speedKmh * 100f)
    }

    // ---- velocimetro moderno ----------------------------------------------
    private fun dibujaGauge(speedKmh: Float, kwS: String, soc: String,
                            rangeS: String, kwh100: String, hora: String): Bitmap {
        val w = 960
        val h = 620
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)

        val bg = Paint().apply { color = Color.rgb(17, 19, 24); isAntiAlias = true }
        c.drawRect(0f, 0f, w.toFloat(), h.toFloat(), bg)

        val cx = w / 2f
        val cy = h * 0.86f
        val r = w * 0.46f
        val startAng = 135f
        val fullSweep = 270f
        val maxSpeed = 160f
        val frac = (speedKmh / maxSpeed).coerceIn(0f, 1f)

        fun pt(angleDeg: Float, rad: Float): Pair<Float, Float> {
            val a = Math.toRadians((angleDeg - 90f).toDouble())
            return (cx + rad * cos(a)).toFloat() to (cy + rad * sin(a)).toFloat()
        }

        // pista
        val pista = Paint().apply {
            color = Color.rgb(42, 46, 55)
            style = Paint.Style.STROKE
            strokeWidth = r * 0.075f
            isAntiAlias = true
            strokeCap = Paint.Cap.ROUND
        }
        c.drawArc(RectF(cx - r, cy - r, cx + r, cy + r), startAng, fullSweep, false, pista)

        // progreso (arco de acento) + halo suave
        val accent = if (kwS.toFloatOrNull() ?: 0f < 0f) Color.rgb(46, 204, 168) else Color.rgb(155, 124, 255)
        val halo = Paint(pista).apply { color = Color.argb(70, Color.red(accent), Color.green(accent), Color.blue(accent)); strokeWidth = r * 0.12f }
        val prog = Paint(pista).apply { color = accent }
        if (frac > 0.003f) {
            c.drawArc(RectF(cx - r, cy - r, cx + r, cy + r), startAng, fullSweep * frac, false, halo)
            c.drawArc(RectF(cx - r, cy - r, cx + r, cy + r), startAng, fullSweep * frac, false, prog)
        }

        // marcas
        val tickMajor = Paint().apply { color = Color.rgb(235, 237, 242); strokeWidth = r * 0.014f; isAntiAlias = true }
        val tickMinor = Paint(tickMajor).apply { color = Color.rgb(120, 126, 138); strokeWidth = r * 0.008f }
        val numP = Paint().apply {
            color = Color.rgb(190, 195, 205)
            textSize = r * 0.10f
            textAlign = Paint.Align.CENTER
            isAntiAlias = true
        }
        var v = 0
        while (v <= maxSpeed.toInt()) {
            val ang = startAng + fullSweep * (v / maxSpeed)
            val major = v % 40 == 0
            val (x1, y1) = pt(ang, r * if (major) 0.86f else 0.90f)
            val (x2, y2) = pt(ang, r * 0.965f)
            c.drawLine(x1, y1, x2, y2, if (major) tickMajor else tickMinor)
            if (major && v > 0) {
                val (tx, ty) = pt(ang, r * 0.74f)
                c.drawText("$v", tx, ty + numP.textSize * 0.35f, numP)
            }
            v += 10
        }

        // aguja
        val needleAng = startAng + fullSweep * frac
        val (nx, ny) = pt(needleAng, r * 0.80f)
        val needle = Paint().apply {
            color = Color.rgb(250, 250, 252)
            strokeWidth = r * 0.016f
            isAntiAlias = true
            strokeCap = Paint.Cap.ROUND
        }
        c.drawLine(cx, cy, nx, ny, needle)
        val hub = Paint().apply { color = accent; isAntiAlias = true }
        c.drawCircle(cx, cy, r * 0.045f, hub)

        // centro digital
        val spdP = Paint().apply {
            color = Color.WHITE
            textSize = r * 0.42f
            textAlign = Paint.Align.CENTER
            isAntiAlias = true
            typeface = android.graphics.Typeface.DEFAULT_BOLD
        }
        c.drawText("%.0f".format(speedKmh), cx, cy - r * 0.10f, spdP)
        val unitP = Paint().apply {
            color = Color.rgb(150, 155, 165)
            textSize = r * 0.11f
            textAlign = Paint.Align.CENTER
            isAntiAlias = true
        }
        c.drawText("km/h", cx, cy + r * 0.02f, unitP)

        // linea de info (SoC · autonomia · consumo · hora)
        val infoP = Paint().apply {
            color = Color.rgb(205, 209, 218)
            textSize = r * 0.115f
            textAlign = Paint.Align.CENTER
            isAntiAlias = true
        }
        val info = listOf(
            if (soc.isEmpty()) "-- %" else "$soc %",
            if (rangeS.isEmpty()) "-- km" else "$rangeS km",
            if (kwh100 == "--") "-- kWh/100" else "$kwh100 kWh/100",
            hora
        ).joinToString("   ")
        c.drawText(info, cx, cy + r * 0.22f, infoP)

        // kW abajo
        val kwP = Paint().apply {
            color = if ((kwS.toFloatOrNull() ?: 0f) < 0f) Color.rgb(46, 204, 168) else Color.rgb(190, 195, 205)
            textSize = r * 0.10f
            textAlign = Paint.Align.CENTER
            isAntiAlias = true
        }
        c.drawText(if (kwS.isEmpty()) "-- kW" else "$kwS kW", cx, cy + r * 0.34f, kwP)

        return bmp
    }
}

// Conduccion con PESTANAS (TabTemplate): Velocidad / Energia / Bateria.
// Cada pestana = PaneTemplate con su bitmap dibujado (tecnica TiresScreen).
// Velocidad por GPS del movil (~1 s); el resto de la nube (refresh ~24 s).
class ConduTabsScreen(carContext: CarContext) : Screen(carContext) {

    private val handler = Handler(Looper.getMainLooper())
    private var ticks = 0
    private var phoneSpeedKmh: Float? = null
    private var lastFixMs: Long = 0
    private var active = "vel"

    private val tabCallback = object : TabTemplate.TabCallback {
        override fun onTabSelected(contentId: String) {
            active = contentId
            invalidate()
        }
    }

    private val refresher = object : Runnable {
        override fun run() {
            ticks++
            if (ticks % 6 == 1) CarBridge.invoke("refresh", null) { }
            invalidate()
            handler.postDelayed(this, 4000)
        }
    }

    private val locListener = LocationListener { loc ->
        if (loc.hasSpeed()) {
            phoneSpeedKmh = loc.speed * 3.6f
            lastFixMs = System.currentTimeMillis()
        }
        invalidate()
    }

    init {
        val lm = carContext.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        if (carContext.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED) {
            try {
                lm.requestLocationUpdates(LocationManager.GPS_PROVIDER, 1000L, 0f, locListener)
            } catch (_: SecurityException) { }
        }
        lifecycle.addObserver(LifecycleEventObserver { _, ev ->
            if (ev == Lifecycle.Event.ON_DESTROY) {
                lm.removeUpdates(locListener)
                handler.removeCallbacks(refresher)
            }
        })
        CarBridge.invoke("refresh", null) { }
        handler.post(refresher)
    }

    private fun d(name: String): String =
        HomeWidgetPlugin.getData(carContext).getString(name, "") ?: ""

    private fun currentSpeed(): Float {
        val gps = phoneSpeedKmh?.takeIf { System.currentTimeMillis() - lastFixMs < 6000 }
        if (gps != null) return gps
        return d("speed").toFloatOrNull() ?: 0f
    }

    override fun onGetTemplate(): Template {
        val contents = when (active) {
            "energia" -> TabContents.Builder(paneEnergia()).build()
            "bateria" -> TabContents.Builder(paneBateria()).build()
            else -> TabContents.Builder(paneVelocidad()).build()
        }
        return TabTemplate.Builder(tabCallback)
            .setHeaderAction(Action.BACK)
            .addTab(Tab.Builder().setTitle("Velocidad").setContentId("vel").build())
            .addTab(Tab.Builder().setTitle("Energia").setContentId("energia").build())
            .addTab(Tab.Builder().setTitle("Bateria").setContentId("bateria").build())
            .setActiveTabContentId(active)
            .setTabContents(contents)
            .build()
    }

    private fun versionRow(): Row =
        Row.Builder()
            .setTitle("API " + carContext.carAppApiLevel)
            .addText("LMB10 3.60.269-beta.1")
            .build()

    private fun paneVelocidad(): Template {
        val speed = currentSpeed()
        val kwS = d("kw")
        val soc = d("soc")
        val range = d("range")
        val hora = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date())
        val kwh100 = if (speed >= 5f && kwS.isNotEmpty() && kwS.toFloatOrNull() != null)
            "%.1f".format(kwS.toFloat() / speed * 100f) else "--"
        val pane = Pane.Builder()
            .setImage(CarIcon.Builder(IconCompat.createWithBitmap(
                dibujaVelocidad(speed, kwS, soc, range, kwh100, hora))).build())
            .addRow(versionRow())
            .build()
        return PaneTemplate.Builder(pane)
            .setTitle("Velocidad")
            .setHeaderAction(Action.BACK)
            .build()
    }

    private fun paneEnergia(): Template {
        val kwS = d("kw")
        val kw = kwS.toFloatOrNull() ?: 0f
        val pane = Pane.Builder()
            .setImage(CarIcon.Builder(IconCompat.createWithBitmap(dibujaEnergia(kw))).build())
            .addRow(versionRow())
            .build()
        return PaneTemplate.Builder(pane)
            .setTitle("Energia")
            .setHeaderAction(Action.BACK)
            .build()
    }

    private fun paneBateria(): Template {
        val pane = Pane.Builder()
            .setImage(CarIcon.Builder(IconCompat.createWithBitmap(
                dibujaBateria(d("soc"), d("range"), d("volt"), d("amp")))).build())
            .addRow(versionRow())
            .build()
        return PaneTemplate.Builder(pane)
            .setTitle("Bateria")
            .setHeaderAction(Action.BACK)
            .build()
    }

    // ---- dibujo (mismas primitivas que el gauge de velocidad) -----------

    private fun pt(color: Int, size: Float, bold: Boolean = false): Paint =
        Paint().apply {
            this.color = color; textSize = size; isAntiAlias = true
            textAlign = Paint.Align.CENTER
            if (bold) typeface = android.graphics.Typeface.DEFAULT_BOLD
        }

    private fun baseBmp(): Pair<Bitmap, Canvas> {
        val bmp = Bitmap.createBitmap(960, 560, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        c.drawColor(Color.rgb(13, 15, 19))
        return bmp to c
    }

    private fun dibujaVelocidad(speedKmh: Float, kwS: String, soc: String,
                                rangeS: String, kwh100: String, hora: String): Bitmap {
        val (bmp, c) = baseBmp()
        val cx = 480f; val cy = 440f; val r = 300f
        miniGauge(c, cx, cy, r, 0f, 180f, speedKmh, false,
            "%.0f".format(speedKmh), "km/h")
        val info = listOf(
            if (soc.isEmpty()) "-- %" else "$soc %",
            if (rangeS.isEmpty()) "-- km" else "$rangeS km",
            if (kwh100 == "--") "-- kWh/100" else "$kwh100 kWh/100",
            hora
        ).joinToString("   ")
        c.drawText(info, cx, cy + r * 0.22f, pt(Color.rgb(205, 209, 218), 30f))
        return bmp
    }

    private fun dibujaEnergia(kw: Float): Bitmap {
        val (bmp, c) = baseBmp()
        val cx = 480f; val cy = 440f; val r = 300f
        miniGauge(c, cx, cy, r, -60f, 170f, kw, true,
            "%.1f".format(kw), "kW")
        c.drawText("izquierda = REGEN (recuperando)   derecha = potencia",
            cx, cy + r * 0.22f, pt(Color.rgb(205, 209, 218), 26f))
        return bmp
    }

    private fun dibujaBateria(soc: String, rangeS: String, volt: String, amp: String): Bitmap {
        val (bmp, c) = baseBmp()
        val pct = (soc.toFloatOrNull() ?: 0f) / 100f
        val bx = 340f; val by = 120f; val bw = 280f; val bh = 200f
        val cuerpo = Paint().apply { color = Color.rgb(48, 52, 61); style = Paint.Style.STROKE; strokeWidth = 10f; isAntiAlias = true }
        c.drawRoundRect(RectF(bx, by, bx + bw, by + bh), 24f, 24f, cuerpo)
        c.drawRoundRect(RectF(bx + bw, by + bh * 0.3f, bx + bw + 28f, by + bh * 0.7f), 8f, 8f, cuerpo)
        if (pct > 0.01f) {
            val fill = Paint().apply {
                color = if (pct < 0.2f) Color.rgb(231, 116, 96) else Color.rgb(46, 204, 168)
                isAntiAlias = true
            }
            val pad = 14f
            c.drawRoundRect(RectF(bx + pad, by + bh - pad - (bh - 2 * pad) * pct, bx + bw - pad, by + bh - pad), 12f, 12f, fill)
        }
        c.drawText(if (soc.isEmpty()) "-- %" else "$soc %", 480f, 420f, pt(Color.WHITE, 120f, bold = true))
        val info = listOf(
            if (rangeS.isEmpty()) "-- km" else "$rangeS km",
            if (volt.isEmpty()) "-- V" else "$volt V",
            if (amp.isEmpty()) "-- A" else "$amp A"
        ).joinToString("     ")
        c.drawText(info, 480f, 500f, pt(Color.rgb(205, 209, 218), 30f))
        return bmp
    }

    // gauge generico (arco 270, marcas cada 10, numeros cada 40)
    private fun miniGauge(c: Canvas, cx: Float, cy: Float, r: Float,
                          vmin: Float, vmax: Float, value: Float, regen: Boolean,
                          digital: String, unit: String) {
        fun frac(v: Float) = ((v - vmin) / (vmax - vmin)).coerceIn(0f, 1f)
        fun ptto(ang: Float, rad: Float): Pair<Float, Float> {
            val a = Math.toRadians((ang - 90f).toDouble())
            return (cx + rad * cos(a)).toFloat() to (cy + rad * sin(a)).toFloat()
        }
        val start = 135f; val sweep = 270f
        val pista = Paint().apply { color = Color.rgb(38, 42, 50); style = Paint.Style.STROKE; strokeWidth = r * 0.075f; isAntiAlias = true; strokeCap = Paint.Cap.ROUND }
        c.drawArc(RectF(cx - r, cy - r, cx + r, cy + r), start, sweep, false, pista)
        if (regen) {
            val zR = Paint(pista).apply { color = Color.rgb(38, 150, 190) }
            c.drawArc(RectF(cx - r, cy - r, cx + r, cy + r), start, sweep * frac(0f), false, zR)
            val zRed = Paint(pista).apply { color = Color.rgb(216, 84, 72) }
            c.drawArc(RectF(cx - r, cy - r, cx + r, cy + r), start + sweep * frac(140f), sweep * (1f - frac(140f)), false, zRed)
        }
        val f = frac(value)
        if (f > 0.004f) {
            val prog = Paint(pista).apply {
                color = if (regen && value < 0f) Color.rgb(46, 204, 168) else Color.rgb(155, 124, 255)
            }
            c.drawArc(RectF(cx - r, cy - r, cx + r, cy + r), start, sweep * f, false, prog)
        }
        val tMaj = Paint().apply { color = Color.rgb(230, 232, 238); strokeWidth = r * 0.013f; isAntiAlias = true }
        val tMin = Paint(tMaj).apply { color = Color.rgb(115, 121, 133); strokeWidth = r * 0.007f }
        val numP = pt(Color.rgb(185, 190, 200), r * 0.105f)
        var v = vmin
        while (v <= vmax + 0.01f) {
            val ang = start + sweep * frac(v)
            val idx = Math.round((v - vmin) / 10f)
            val major = idx % 2 == 0
            val (x1, y1) = ptto(ang, r * if (major) 0.855f else 0.895f)
            val (x2, y2) = ptto(ang, r * 0.965f)
            c.drawLine(x1, y1, x2, y2, if (major) tMaj else tMin)
            if (idx % 4 == 0 && v > vmin) {
                val (tx, ty) = ptto(ang, r * 0.735f)
                c.drawText("%.0f".format(v), tx, ty + numP.textSize * 0.35f, numP)
            }
            v += 10f
        }
        val na = start + sweep * f
        val (nx, ny) = ptto(na, r * 0.80f)
        val needle = Paint().apply { color = Color.rgb(250, 250, 252); strokeWidth = r * 0.014f; isAntiAlias = true; strokeCap = Paint.Cap.ROUND }
        c.drawLine(cx, cy, nx, ny, needle)
        val hub = Paint().apply { color = Color.rgb(210, 213, 220); isAntiAlias = true }
        c.drawCircle(cx, cy, r * 0.04f, hub)
        c.drawText(digital, cx, cy - r * 0.06f, pt(Color.WHITE, r * 0.30f, bold = true))
        c.drawText(unit, cx, cy + r * 0.06f, pt(Color.rgb(150, 155, 165), r * 0.10f))
    }
}
