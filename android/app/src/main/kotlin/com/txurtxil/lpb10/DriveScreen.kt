package com.txurtxil.lpb10

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.location.LocationListener
import android.location.LocationManager
import android.os.Handler
import android.os.Looper
import android.view.Surface
import androidx.car.app.AppManager
import androidx.car.app.CarContext
import androidx.car.app.model.Action
import androidx.car.app.model.ItemList
import androidx.car.app.model.ListTemplate
import androidx.car.app.model.Row
import androidx.car.app.navigation.model.MapController
import androidx.car.app.navigation.model.MapWithContentTemplate

import androidx.car.app.Screen
import androidx.car.app.SurfaceCallback
import androidx.car.app.SurfaceContainer
import androidx.car.app.model.Template
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

// Cuadro de conduccion (issue #18; diseno pedido por el grupo, mockup de
// InJotec): SUPERFICIE LIBRE (categoria NAVIGATION, sideloaded sin Play).
// Dibuja: velocimetro grande (izq), reloj de potencia con zona REGEN
// (dcha), widget de bateria al centro y franja desnivel+hora arriba.
// Velocidad por GPS del movil (~1 s); el resto de la nube (refresh ~24 s).
class DriveScreen(carContext: CarContext) : Screen(carContext) {

    private val handler = Handler(Looper.getMainLooper())
    private var ticks = 0
    private var phoneSpeedKmh: Float? = null
    private var lastFixMs: Long = 0
    private var lastDrawMs: Long = 0L
    private var container: SurfaceContainer? = null

    private val surfaceCb = object : SurfaceCallback {
        override fun onSurfaceAvailable(c: SurfaceContainer) { container = c; redraw() }
        override fun onVisibleAreaChanged(visibleArea: Rect) { redraw() }
        override fun onStableAreaChanged(visibleArea: Rect) { redraw() }
        override fun onSurfaceDestroyed(c: SurfaceContainer) { if (container === c) container = null }
    }

    private val refresher = object : Runnable {
        override fun run() {
            ticks++
            if (ticks % 6 == 1) CarBridge.invoke("refresh", null) { }
            invalidate()
            redraw()
            handler.postDelayed(this, 4000)
        }
    }

    private val locListener = LocationListener { loc ->
        if (loc.hasSpeed()) {
            phoneSpeedKmh = loc.speed * 3.6f
            lastFixMs = System.currentTimeMillis()
        }
        redraw()
    }

    init {
        carContext.getCarService(AppManager::class.java).setSurfaceCallback(surfaceCb)
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
        // API 8 en el B10 => superficie viable. Via moderna para apps que
        // pintan su propio contenido (mapa/cuadro): MapWithContentTemplate
        // (la que usa ABRP). El surface la host pinta detras; el contenido
        // (una lista minima con API/version) va al lado.
        val content = ListTemplate.Builder()
            .setTitle("LMB10 - Conduccion")
            .setHeaderAction(Action.BACK)
            .setSingleList(ItemList.Builder()
                .addItem(Row.Builder()
                    .setTitle("API " + carContext.carAppApiLevel)
                    .addText("beta 3.60.268-beta.4")
                    .build())
                .build())
            .build()
        val mapController = MapController.Builder()
            .setPanModeListener { }
            .build()
        return MapWithContentTemplate.Builder()
            .setMapController(mapController)
            .setContentTemplate(content)
            .build()
    }

    private fun redraw() {
        val now = System.currentTimeMillis()
        if (now - lastDrawMs < 800) return
        lastDrawMs = now
        val cont = container ?: return
        val surface: Surface = cont.surface ?: return
        val canvas: Canvas = try { surface.lockCanvas(null) } catch (_: Exception) { return } ?: return
        try {
            dibujaDashboard(canvas)
        } finally {
            try { surface.unlockCanvasAndPost(canvas) } catch (_: Exception) { }
        }
    }

    private fun currentSpeed(): Float {
        val gps = phoneSpeedKmh?.takeIf { System.currentTimeMillis() - lastFixMs < 6000 }
        if (gps != null) return gps
        return d("speed").toFloatOrNull() ?: 0f
    }

    // ---- dibujo -----------------------------------------------------------

    private fun pText(color: Int, size: Float, bold: Boolean = false): Paint =
        Paint().apply {
            this.color = color
            textSize = size
            isAntiAlias = true
            textAlign = Paint.Align.CENTER
            if (bold) typeface = android.graphics.Typeface.DEFAULT_BOLD
        }

    private fun dibujaDashboard(c: Canvas) {
        val w = c.width.toFloat()
        val h = c.height.toFloat()
        if (w <= 0f || h <= 0f) return

        val speed = currentSpeed()
        val kw = d("kw").toFloatOrNull() ?: 0f
        val kwS = d("kw")
        val soc = d("soc")
        val range = d("range")
        val hora = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date())
        val fecha = SimpleDateFormat("dd/MM/yyyy", Locale.getDefault()).format(Date())
        val kwh100 = if (speed >= 5f && kwS.isNotEmpty())
            "%.1f".format(kw / speed * 100f) else "--"

        c.drawColor(Color.rgb(13, 15, 19))

        val r = min(w, h) * 0.315f
        val cy = h * 0.66f
        val cLx = w * 0.29f
        val cRx = w * 0.71f
        val startAng = 135f
        val sweep = 270f

        val topP = pText(Color.rgb(205, 209, 218), h * 0.052f)
        c.drawText("Desnivel: -- m (issue #17)      $hora  $fecha", w / 2f, h * 0.085f, topP)

        dibujaGauge(
            c, cLx, cy, r, startAng, sweep, 0f, 180f, speed,
            accent = Color.rgb(155, 124, 255),
            digital = "%.0f".format(speed), unit = "km/h"
        )
        dibujaGauge(
            c, cRx, cy, r, startAng, sweep, -60f, 170f, kw,
            accent = Color.rgb(155, 124, 255),
            digital = kwS.ifEmpty { "0" }, unit = "kW", regen = true
        )

        // widget bateria central
        val bw = w * 0.075f
        val bh = h * 0.115f
        val bx = w / 2f - bw / 2f
        val by = h * 0.30f
        val cuerpo = Paint().apply { color = Color.rgb(48, 52, 61); style = Paint.Style.STROKE; strokeWidth = h * 0.008f; isAntiAlias = true }
        val fillPct = (soc.toFloatOrNull() ?: 0f) / 100f
        c.drawRoundRect(RectF(bx, by, bx + bw, by + bh), bw * 0.12f, bw * 0.12f, cuerpo)
        c.drawRoundRect(RectF(bx + bw, by + bh * 0.30f, bx + bw + bw * 0.10f, by + bh * 0.70f), 4f, 4f, cuerpo)
        if (fillPct > 0.01f) {
            val fill = Paint().apply {
                color = if (fillPct < 0.2f) Color.rgb(231, 116, 96) else Color.rgb(46, 204, 168)
                isAntiAlias = true
            }
            val pad = bw * 0.08f
            c.drawRoundRect(
                RectF(bx + pad, by + bh - pad - (bh - 2 * pad) * fillPct, bx + bw - pad, by + bh - pad),
                6f, 6f, fill)
        }
        val socP = pText(Color.WHITE, h * 0.075f, bold = true)
        c.drawText(if (soc.isEmpty()) "-- %" else "$soc %", w / 2f, by + bh + h * 0.075f, socP)

        val botP = pText(Color.rgb(185, 190, 200), h * 0.048f)
        val info = listOf(
            if (range.isEmpty()) "-- km" else "$range km",
            if (kwh100 == "--") "-- kWh/100" else "$kwh100 kWh/100"
        ).joinToString("      ")
        c.drawText(info, w / 2f, h * 0.955f, botP)
    }

    private fun dibujaGauge(
        c: Canvas, cx: Float, cy: Float, r: Float,
        startAng: Float, sweep: Float, vmin: Float, vmax: Float, value: Float,
        accent: Int, digital: String, unit: String, regen: Boolean = false
    ) {
        fun fracOf(v: Float): Float = ((v - vmin) / (vmax - vmin)).coerceIn(0f, 1f)
        fun pt(angleDeg: Float, rad: Float): Pair<Float, Float> {
            val a = Math.toRadians((angleDeg - 90f).toDouble())
            return (cx + rad * cos(a)).toFloat() to (cy + rad * sin(a)).toFloat()
        }

        val pista = Paint().apply {
            color = Color.rgb(38, 42, 50)
            style = Paint.Style.STROKE
            strokeWidth = r * 0.075f
            isAntiAlias = true
            strokeCap = Paint.Cap.ROUND
        }
        c.drawArc(RectF(cx - r, cy - r, cx + r, cy + r), startAng, sweep, false, pista)

        if (regen) {
            val zRegen = Paint(pista).apply { color = Color.rgb(38, 150, 190) }
            c.drawArc(RectF(cx - r, cy - r, cx + r, cy + r), startAng, sweep * fracOf(0f), false, zRegen)
            val zRed = Paint(pista).apply { color = Color.rgb(216, 84, 72) }
            c.drawArc(RectF(cx - r, cy - r, cx + r, cy + r), startAng + sweep * fracOf(140f), sweep * (1f - fracOf(140f)), false, zRed)
        }

        val f = fracOf(value)
        if (f > 0.004f) {
            val prog = Paint(pista).apply {
                color = if (regen && value < 0f) Color.rgb(46, 204, 168) else accent
            }
            c.drawArc(RectF(cx - r, cy - r, cx + r, cy + r), startAng, sweep * f, false, prog)
        }

        val tickMaj = Paint().apply { color = Color.rgb(230, 232, 238); strokeWidth = r * 0.013f; isAntiAlias = true }
        val tickMin = Paint(tickMaj).apply { color = Color.rgb(115, 121, 133); strokeWidth = r * 0.007f }
        val numP = pText(Color.rgb(185, 190, 200), r * 0.105f)
        var v = vmin
        while (v <= vmax + 0.01f) {
            val ang = startAng + sweep * fracOf(v)
            val idx = ((v - vmin) / 10f).toInt()
            val major = idx % 2 == 0
            val (x1, y1) = pt(ang, r * if (major) 0.855f else 0.895f)
            val (x2, y2) = pt(ang, r * 0.965f)
            c.drawLine(x1, y1, x2, y2, if (major) tickMaj else tickMin)
            if (idx % 4 == 0 && v > vmin) {
                val (tx, ty) = pt(ang, r * 0.735f)
                c.drawText("%.0f".format(v), tx, ty + numP.textSize * 0.35f, numP)
            }
            v += 10f
        }

        val needleAng = startAng + sweep * f
        val (nx, ny) = pt(needleAng, r * 0.80f)
        val needle = Paint().apply {
            color = Color.rgb(250, 250, 252)
            strokeWidth = r * 0.014f
            isAntiAlias = true
            strokeCap = Paint.Cap.ROUND
        }
        c.drawLine(cx, cy, nx, ny, needle)
        val hub = Paint().apply { color = Color.rgb(210, 213, 220); isAntiAlias = true }
        c.drawCircle(cx, cy, r * 0.04f, hub)

        val digP = pText(Color.WHITE, r * 0.30f, bold = true)
        c.drawText(digital, cx, cy - r * 0.06f, digP)
        val unitP = pText(Color.rgb(150, 155, 165), r * 0.10f)
        c.drawText(unit, cx, cy + r * 0.06f, unitP)
    }
}
