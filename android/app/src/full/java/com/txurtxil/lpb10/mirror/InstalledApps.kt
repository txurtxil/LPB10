/*
 * SPDX-FileCopyrightText: 2026 txurtxil
 * SPDX-License-Identifier: GPL-3.0-only
 */

package com.txurtxil.lpb10.mirror.extension

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.drawable.Drawable
import android.os.Build

data class LauncherAppInfo(
    val packageName: String,
    val label: String,
    val icon: Drawable,
)

/**
 * List installed apps that have their own launcher icon. Uses the CATEGORY_LAUNCHER intent
 * query, which Android exempts from package visibility restrictions since it's the standard
 * mechanism for building launchers — no QUERY_ALL_PACKAGES permission needed.
 */
fun Context.queryLauncherApps(): List<LauncherAppInfo> {
    val pm = packageManager
    val intent = Intent(Intent.ACTION_MAIN).apply {
        addCategory(Intent.CATEGORY_LAUNCHER)
    }

    val resolveInfos = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        pm.queryIntentActivities(intent, PackageManager.ResolveInfoFlags.of(0))
    } else {
        @Suppress("DEPRECATION")
        pm.queryIntentActivities(intent, 0)
    }

    return resolveInfos
        .filter { it.activityInfo.packageName != packageName }
        .distinctBy { it.activityInfo.packageName }
        .map {
            LauncherAppInfo(
                packageName = it.activityInfo.packageName,
                label = it.loadLabel(pm).toString(),
                icon = it.loadIcon(pm),
            )
        }
        .sortedBy { it.label.lowercase() }
}
