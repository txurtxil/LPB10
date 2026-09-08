package com.txurtxil.lpb10

import android.content.Context
import java.io.File
import java.io.FileOutputStream

/** Registro con timestamp de cada vez que driving.flag se pone o se quita
 *  (ver CarBtReceiver). TripRebuild (lado Dart) lo cruza con trips.jsonl
 *  para distinguir una parada real del coche (Bluetooth desconectado varios
 *  minutos) de un simple hueco de sondeo, y asi cortar la ruta en dos en vez
 *  de fusionarla con la siguiente.
 *
 *  Mismo patron de recorte por tamano que CarLog.kt: aqui solo hay una linea
 *  por conexion/desconexion real (no por cada sondeo de 90s), asi que crece
 *  muy poco, pero se recorta igual por si el Bluetooth parpadea mucho un dia
 *  suelto.
 */
object CarDriveEvents {
    private const val MAX_LINES = 2000
    private const val MAX_BYTES = 100000L

    private fun file(ctx: Context): File {
        val docs = File(ctx.filesDir.parentFile, "app_flutter/lmb10_history")
        docs.mkdirs()
        return File(docs, "driving_events.jsonl")
    }

    /** event: "connect" o "disconnect", mismo momento en que se pone/quita
     *  driving.flag. */
    @Synchronized
    fun log(ctx: Context, event: String) {
        try {
            val f = file(ctx)
            if (f.exists() && f.length() > MAX_BYTES) {
                val lines = f.readLines()
                val keep = if (lines.size > MAX_LINES)
                    lines.subList(lines.size - MAX_LINES, lines.size) else lines
                f.writeText(keep.joinToString("\n") + "\n")
            }
            val linea = "{\"ts\":" + System.currentTimeMillis() +
                ",\"event\":\"" + event + "\"}\n"
            FileOutputStream(f, true).use { out ->
                out.write(linea.toByteArray())
                out.flush()
                out.fd.sync()
            }
        } catch (_: Exception) {}
    }
}
