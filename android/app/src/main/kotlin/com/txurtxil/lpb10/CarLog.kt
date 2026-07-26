package com.txurtxil.lpb10

import android.content.Context
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Log persistente a archivo para diagnosticar Android Auto sin adb.
 *  Se escribe en Documents/lmb10_history/carlog.txt y lo lee la app. */
object CarLog {
    private const val MAX_LINES = 300
    private fun file(ctx: Context): File {
        val dir = File(ctx.getExternalFilesDir(null)?.parentFile, "app_flutter")
        // Ruta equivalente a getApplicationDocumentsDirectory de Flutter
        val docs = File(ctx.filesDir.parentFile, "app_flutter/lmb10_history")
        docs.mkdirs()
        return File(docs, "carlog.txt")
    }

    @Synchronized
    fun log(ctx: Context, tag: String, msg: String) {
        try {
            val ts = SimpleDateFormat("MM-dd HH:mm:ss", Locale.US).format(Date())
            val f = file(ctx)
            val lines = if (f.exists()) f.readLines().toMutableList() else mutableListOf()
            lines.add("$ts [$tag] $msg")
            while (lines.size > MAX_LINES) lines.removeAt(0)
            f.writeText(lines.joinToString("\n"))
        } catch (_: Exception) {}
    }
}
