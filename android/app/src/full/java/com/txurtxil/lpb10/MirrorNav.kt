package com.txurtxil.lpb10

import androidx.car.app.CarContext
import androidx.car.app.Screen
import com.txurtxil.lpb10.mirror.mirror.DisplayScreen

// Fusion espejo (flavor full): entrada del menu de CarMainScreen hacia el
// espejo de pantalla (port de MirrorMobile/LMonitor).
object MirrorNav {
    const val ENABLED = true
    fun screen(ctx: CarContext): Screen = DisplayScreen(ctx)
}
