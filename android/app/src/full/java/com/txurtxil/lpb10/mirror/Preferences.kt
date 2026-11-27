/*
 * SPDX-FileCopyrightText: 2023-2024 Andrew Gunnerson
 * SPDX-License-Identifier: GPL-3.0-only
 */

package com.txurtxil.lpb10.mirror

import android.content.Context
import android.content.SharedPreferences.OnSharedPreferenceChangeListener
import androidx.core.content.edit
import androidx.preference.PreferenceManager

class Preferences(context: Context) {
    companion object {
        // Keep in the same order as the helper functions below.
        const val PREF_DEBUG_MODE = "debug_mode"
        private const val PREF_AUTO_START = "auto_start"
        private const val PREF_WAKE_LOCK = "wake_lock"
        private const val PREF_SPEED_THRESHOLD = "speed_threshold"
        private const val PREF_LAST_SURFACE_INFO = "last_surface_info"
        private const val PREF_LAUNCHER_APPS = "launcher_apps"
        private const val PREF_STOP_ON_DISCONNECT = "stop_on_disconnect"
        private const val PREF_WIDTH_OFFSET = "width_offset"
        private const val PREF_HEIGHT_OFFSET = "height_offset"
        private const val PREF_FORCE_HORIZONTAL = "force_horizontal"

        // Presets del umbral de velocidad (m/s), se ciclan al tocar la preferencia.
        // 0.001f es el valor original de upstream; se mantiene como preset[0] para que
        // el comportamiento no cambie salvo que el usuario elija otro explícitamente.
        val SPEED_THRESHOLD_PRESETS = floatArrayOf(0.001f, 0.5f, 1.0f, 1.5f, 2.0f)

        // Presets del offset de pixeles (ancho/alto), se ciclan al tocar la preferencia.
        // Valores de partida sin validar contra la resolucion real del B10 -- ajustar
        // cuando se sepa que tamano de superficie da el coche de verdad.
        val PIXEL_OFFSET_PRESETS = intArrayOf(0, 8, -8, 16, -16, 32, -32, 64, -64)
    }

    private val prefs = PreferenceManager.getDefaultSharedPreferences(context)

    fun registerListener(listener: OnSharedPreferenceChangeListener) {
        prefs.registerOnSharedPreferenceChangeListener(listener)
    }

    fun unregisterListener(listener: OnSharedPreferenceChangeListener) {
        prefs.unregisterOnSharedPreferenceChangeListener(listener)
    }

    var isDebugMode: Boolean
        get() = prefs.getBoolean(PREF_DEBUG_MODE, false)
        set(enabled) = prefs.edit { putBoolean(PREF_DEBUG_MODE, enabled) }

    var autoStart: Boolean
        get() = prefs.getBoolean(PREF_AUTO_START, true)
        set(enabled) = prefs.edit { putBoolean(PREF_AUTO_START, enabled) }

    var wakeLock: Boolean
        get() = prefs.getBoolean(PREF_WAKE_LOCK, true)
        set(enabled) = prefs.edit { putBoolean(PREF_WAKE_LOCK, enabled) }

    var speedThreshold: Float
        get() = prefs.getFloat(PREF_SPEED_THRESHOLD, SPEED_THRESHOLD_PRESETS[0])
        set(value) = prefs.edit { putFloat(PREF_SPEED_THRESHOLD, value) }

    var lastSurfaceInfo: String
        get() = prefs.getString(PREF_LAST_SURFACE_INFO, "") ?: ""
        set(value) = prefs.edit { putString(PREF_LAST_SURFACE_INFO, value) }

    var launcherApps: Set<String>
        get() = prefs.getStringSet(PREF_LAUNCHER_APPS, emptySet()) ?: emptySet()
        set(value) = prefs.edit { putStringSet(PREF_LAUNCHER_APPS, value) }

    // true (default, comportamiento original): al desconectar de Android Auto se
    // libera el permiso de MediaProjection por completo.
    // false: se mantiene la sesion de captura viva en segundo plano para reanudar
    // sin volver a pedir permiso al reconectar -- coste: notificacion persistente
    // y wakelock activos mientras el coche este desconectado.
    var stopOnDisconnect: Boolean
        get() = prefs.getBoolean(PREF_STOP_ON_DISCONNECT, true)
        set(enabled) = prefs.edit { putBoolean(PREF_STOP_ON_DISCONNECT, enabled) }

    // Ajuste manual en pixeles del tamano pedido a createVirtualDisplay().
    // Positivo encoge (recupera un borde cortado), negativo expande (rellena
    // una franja negra). 0 = sin ajuste, comportamiento original.
    var widthOffset: Int
        get() = prefs.getInt(PREF_WIDTH_OFFSET, 0)
        set(value) = prefs.edit { putInt(PREF_WIDTH_OFFSET, value) }

    var heightOffset: Int
        get() = prefs.getInt(PREF_HEIGHT_OFFSET, 0)
        set(value) = prefs.edit { putInt(PREF_HEIGHT_OFFSET, value) }

    // Solo recuerda la ultima eleccion del usuario -- forzar/restaurar de verdad
    // ocurre en SettingsScreen al cambiar este valor.
    var forceHorizontal: Boolean
        get() = prefs.getBoolean(PREF_FORCE_HORIZONTAL, false)
        set(enabled) = prefs.edit { putBoolean(PREF_FORCE_HORIZONTAL, enabled) }
}
