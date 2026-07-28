package com.txurtxil.lpb10

import android.content.Context
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Log persistente a archivo para diagnosticar Android Auto sin adb.
 *  Se escribe en app_flutter/lmb10_history/carlog.txt y lo lee la app.
 *
 *  IMPORTANTE. La version anterior hacia readLines + writeText en CADA linea,
 *  o sea una reescritura completa del fichero. El lado Dart escribe en ese
 *  mismo fichero por su cuenta, fuera de este lock, asi que cualquiera de los
 *  dos podia machacar las lineas del otro. Se perdian trazas en silencio y eso
 *  invalidaba los diagnosticos de navegacion. Ahora se escribe en modo APPEND
 *  con flush y fsync, que sobre el mismo fichero tolera mucho mejor la carrera.
 *
 *  El recorte ya no se hace por linea: solo cuando el fichero pasa de MAX_BYTES.
 */
object CarLog {
    private const val MAX_LINES = 400
    private const val MAX_BYTES = 120000L

    private fun file(ctx: Context): File {
        val docs = File(ctx.filesDir.parentFile, "app_flutter/lmb10_history")
        docs.mkdirs()
        return File(docs, "carlog.txt")
    }

    @Synchronized
    fun log(ctx: Context, tag: String, msg: String) {
        try {
            val ts = SimpleDateFormat("MM-dd HH:mm:ss", Locale.US).format(Date())
            val f = file(ctx)
            if (f.exists() && f.length() > MAX_BYTES) {
                val lines = f.readLines()
                val keep = if (lines.size > MAX_LINES)
                    lines.subList(lines.size - MAX_LINES, lines.size) else lines
                f.writeText(keep.joinToString("\n") + "\n")
            }
            FileOutputStream(f, true).use { out ->
                out.write((ts + " [" + tag + "] " + msg + "\n").toByteArray())
                out.flush()
                out.fd.sync()
            }
        } catch (_: Exception) {}
    }
}
