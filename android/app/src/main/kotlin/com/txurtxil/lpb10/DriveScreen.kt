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
    private var lastAlt: Double? = null
    private var startAlt: Double? = null
    private var climb = 0.0
    private var descent = 0.0
    private var maxAlt: Double? = null
    private var minAlt: Double? = null

    private val refresher = object : Runnable {
        override fun run() {
            ticks++
            if (ticks % 5 == 1) CarBridge.invoke("refresh", null) { }
            invalidate()
            handler.postDelayed(this, 3000)
        }
    }

    private val locListener = LocationListener { loc ->
        // FIX LAG: el listener del pane NO llamaba a invalidate() => la
        // velocidad solo se repintaba con el refresher (3 s). Ahora cada
        // fix GPS (500 ms fundido) repinta enseguida.
        if (loc.hasSpeed()) {
            phoneSpeedKmh = loc.speed * 3.6f
            lastFixMs = System.currentTimeMillis()
        }
        if (loc.hasAltitude()) {
            val a = loc.altitude
            val prev = lastAlt
            if (prev != null) {
                val dd = a - prev
                if (dd > 2.0) climb += dd
                else if (dd < -2.0) descent += -dd
            } else {
                startAlt = a
            }
            lastAlt = a
            maxAlt = if (maxAlt == null || a > maxAlt!!) a else maxAlt
            minAlt = if (minAlt == null || a < minAlt!!) a else minAlt
        }
        invalidate()
    }

    init {
        val lm = carContext.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        if (carContext.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED) {
            try {
                if (android.os.Build.VERSION.SDK_INT >= 31) {
                    lm.requestLocationUpdates(LocationManager.FUSED_PROVIDER, 500L, 0f, locListener)
                } else {
                    lm.requestLocationUpdates(LocationManager.GPS_PROVIDER, 500L, 0f, locListener)
                }
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

        val altTxt = if (lastAlt == null) "-- m" else "%.0f m".format(lastAlt)
        val iniTxt = if (startAlt == null || lastAlt == null) "-- m"
                     else "%+.0f m".format(lastAlt!! - startAlt!!)
        val subBajTxt = "+%.0f m  -%.0f m".format(climb, descent)
        val maxMinTxt = "max %.0f  min %.0f".format(maxAlt ?: 0.0, minAlt ?: 0.0)
        val gauge = dibujaGauge(speed, kwS, soc, range, kwh100, hora,
            altTxt, iniTxt, subBajTxt, maxMinTxt)

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
            .addRow(Row.Builder().setTitle("API " + carContext.carAppApiLevel).addText("3.60.269-beta.6").build())
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
                            rangeS: String, kwh100: String, hora: String,
                            altTxt: String, iniTxt: String,
                            subBajTxt: String, maxMinTxt: String): Bitmap {
        val w = 960
        val h = 620
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)

        val bg = Paint().apply { color = Color.rgb(17, 19, 24); isAntiAlias = true }
        c.drawRect(0f, 0f, w.toFloat(), h.toFloat(), bg)

        val cx = w * 0.36f
        val cy = h * 0.86f
        val r = w * 0.335f
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

        // columna de altitud (issue #17) fusionada en la misma caja
        val ax = w * 0.78f
        fun ap(color: Int, size: Float, bold: Boolean = false) = Paint().apply {
            this.color = color; textSize = size; isAntiAlias = true
            textAlign = Paint.Align.CENTER
            if (bold) typeface = android.graphics.Typeface.DEFAULT_BOLD
        }
        c.drawText("ALTITUD", ax, 150f, ap(Color.rgb(150, 155, 165), 30f))
        c.drawText(altTxt, ax, 280f, ap(Color.WHITE, 105f, bold = true))
        c.drawText("desde inicio: $iniTxt", ax, 350f, ap(Color.rgb(46, 204, 168), 32f))
        c.drawText(subBajTxt, ax, 415f, ap(Color.rgb(205, 209, 218), 30f))
        c.drawText(maxMinTxt, ax, 470f, ap(Color.rgb(150, 155, 165), 26f))

        return bmp
    }
}
