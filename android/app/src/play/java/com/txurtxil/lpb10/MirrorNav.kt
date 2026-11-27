package com.txurtxil.lpb10

import androidx.car.app.CarContext
import androidx.car.app.Screen

// Flavor play: el espejo NO existe (norma del owner: multimedia solo fuera de Play).
object MirrorNav {
    const val ENABLED = false
    fun screen(ctx: CarContext): Screen =
        throw UnsupportedOperationException("Espejo solo disponible en flavor full")
}
