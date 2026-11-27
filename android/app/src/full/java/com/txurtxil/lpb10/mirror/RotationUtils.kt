/*
 * SPDX-FileCopyrightText: 2026 txurtxil
 * SPDX-License-Identifier: GPL-3.0-only
 */

package com.txurtxil.lpb10.mirror.extension

import android.content.Context
import android.provider.Settings
import android.view.Surface

/** Whether we currently hold the special WRITE_SETTINGS permission. */
fun Context.canWriteSystemSettings(): Boolean = Settings.System.canWrite(this)

/**
 * Disables system auto-rotate and forces landscape. This changes the whole phone's
 * orientation, not just this app's -- so whatever is on screen (and therefore whatever
 * gets mirrored) ends up landscape too.
 */
fun Context.forceLandscapeRotation() {
    Settings.System.putInt(contentResolver, Settings.System.ACCELEROMETER_ROTATION, 0)
    Settings.System.putInt(contentResolver, Settings.System.USER_ROTATION, Surface.ROTATION_90)
}

/** Re-enables normal system auto-rotate. */
fun Context.restoreAutoRotation() {
    Settings.System.putInt(contentResolver, Settings.System.ACCELEROMETER_ROTATION, 1)
}
