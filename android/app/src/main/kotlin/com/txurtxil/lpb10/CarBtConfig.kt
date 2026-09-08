package com.txurtxil.lpb10

import android.content.Context

/** Lista de MACs Bluetooth que el usuario ha marcado como "del coche".
 *
 *  Compartida entre CarBtReceiver (filtra el broadcast para no reaccionar a
 *  auriculares, reloj, etc.) y MainActivity (expone a Dart la lista de
 *  dispositivos emparejados para que el usuario elija). Vive en las mismas
 *  prefs que connected_macs, pero es una clave distinta: esta es
 *  configuracion persistente del usuario, no estado de conexion en curso.
 *
 *  Set vacio = sin configurar todavia -> CarBtReceiver mantiene el
 *  comportamiento antiguo (reacciona a cualquier Bluetooth) para no romper
 *  la deteccion de quien todavia no ha pasado por la pantalla nueva.
 */
object CarBtConfig {
    private const val PREFS = "lmb10_bt"
    private const val KEY_CAR_MACS = "car_macs"

    fun carMacs(ctx: Context): Set<String> =
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getStringSet(KEY_CAR_MACS, emptySet()) ?: emptySet()

    fun setCarMacs(ctx: Context, macs: Set<String>) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putStringSet(KEY_CAR_MACS, macs)
            .apply()
    }
}
