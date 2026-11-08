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
import androidx.car.app.model.Template
import androidx.core.graphics.drawable.IconCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver

// Altimetria (issue #17): otra "caja" tipo pane con altitud. GPS del
// movil (barometro si lo tiene = precision de metros). Muestra: altitud
// actual, altitud al abrir la pantalla, desnivel acumulado +/− y max/min.
// Filtro de ruido: solo cuenta deltas > 2 m.
class AltimetryScreen(carContext: CarContext) : Screen(carContext) {

    private val handler = Handler(Looper.getMainLooper())
    private var lastAlt: Double? = null
    private var startAlt: Double? = null
    private var climb = 0.0
    private var descent = 0.0
    private var maxAlt: Double? = null
    private var minAlt: Double? = null

    private val refresher = object : Runnable {
        override fun run() { invalidate(); handler.postDelayed(this, 3000) }
    }

    private val locListener = LocationListener { loc ->
        if (loc.hasAltitude()) {
            val a = loc.altitude
            val prev = lastAlt
            if (prev != null) {
                val d = a - prev
                if (d > 2.0) climb += d
                else if (d < -2.0) descent += -d
            } else {
                startAlt = a
            }
            lastAlt = a
            maxAlt = if (maxAlt == null || a > maxAlt!!) a else maxAlt
            minAlt = if (minAlt == null || a < minAlt!!) a else minAlt
            invalidate()
        }
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
        handler.post(refresher)
    }

    override fun onGetTemplate(): Template {
        val alt = lastAlt
        val bmp = Bitmap.createBitmap(960, 560, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        c.drawColor(Color.rgb(13, 15, 19))
        fun pt(color: Int, size: Float, bold: Boolean = false) = Paint().apply {
            this.color = color; textSize = size; isAntiAlias = true; textAlign = Paint.Align.CENTER
            if (bold) typeface = android.graphics.Typeface.DEFAULT_BOLD
        }
        c.drawText("ALTITUD", 480f, 90f, pt(Color.rgb(150, 155, 165), 34f))
        c.drawText(if (alt == null) "-- m" else "%.0f m".format(alt), 480f, 260f, pt(Color.WHITE, 130f, bold = true))
        val linea1 = "inicio: " + (if (startAlt == null || alt == null) "-- m" else "%+.0f m".format(alt - startAlt!!))
        val linea2 = "subida +%.0f m   bajada -%.0f m".format(climb, descent)
        val linea3 = "max %.0f m   min %.0f m".format(maxAlt ?: 0.0, minAlt ?: 0.0)
        c.drawText(linea1, 480f, 350f, pt(Color.rgb(46, 204, 168), 40f))
        c.drawText(linea2, 480f, 430f, pt(Color.rgb(205, 209, 218), 34f))
        c.drawText(linea3, 480f, 490f, pt(Color.rgb(150, 155, 165), 30f))
        val pane = Pane.Builder()
            .setImage(CarIcon.Builder(IconCompat.createWithBitmap(bmp)).build())
            .addRow(Row.Builder().setTitle("LMB10 3.60.269-beta.7").addText("API " + carContext.carAppApiLevel).build())
            .addRow(Row.Builder().setTitle(if (alt == null) "-- m" else "%.0f m".format(alt)).addText("Altitud actual").build())
            .addRow(Row.Builder().setTitle(if (startAlt == null || alt == null) "-- m" else "%+.0f m".format(alt - startAlt!!)).addText("Desde que abriste la pantalla").build())
            .addRow(Row.Builder().setTitle("+%.0f m / -%.0f m".format(climb, descent)).addText("Subida / bajada acumulada").build())
            .addRow(Row.Builder().setTitle("max %.0f m  min %.0f m".format(maxAlt ?: 0.0, minAlt ?: 0.0)).addText("Extremos").build())
            .build()
        return PaneTemplate.Builder(pane)
            .setTitle("LMB10 - Altimetria")
            .setHeaderAction(Action.BACK)
            .build()
    }
}
