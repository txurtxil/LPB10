package com.txurtxil.lpb10

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.content.pm.ServiceInfo
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import java.io.File
import java.util.Locale

/** Foreground service minimo: solo existe para poder mantener vivo el
 *  sondeo cada 90s mientras se conduce (Android mata el sondeo normal de
 *  15 min o lo retrasa mucho en cuanto la app pasa a segundo plano).
 *
 *  No hace ningun trabajo el mismo: escribe un fichero-flag que Dart
 *  comprueba (driving.flag, junto a carlog.txt) y dispara la primera
 *  tarea de WorkManager; el propio Dart se reencadena solo mientras el
 *  flag siga presente (ver backgroundCallbackDispatcher en main.dart).
 */
class CarDriveService : Service() {
    companion object {
        private const val CHANNEL_ID = "lmb10_drive"
        private const val NOTIF_ID = 4200
        private const val ACTION_STOP = "com.txurtxil.lpb10.DRIVE_STOP"

        fun start(ctx: Context) {
            val i = Intent(ctx, CarDriveService::class.java)
            ctx.startForegroundService(i)
        }

        fun stop(ctx: Context) {
            ctx.startService(Intent(ctx, CarDriveService::class.java).setAction(ACTION_STOP))
        }

        private fun flagFile(ctx: Context): File {
            val docs = File(ctx.filesDir.parentFile, "app_flutter/lmb10_history")
            docs.mkdirs()
            return File(docs, "driving.flag")
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            pararDeVerdad()
            return START_NOT_STICKY
        }
        arrancarDeVerdad()
        return START_NOT_STICKY
    }

    private fun arrancarDeVerdad() {
        // Traza de entrada. Sin esto no se puede distinguir "el servicio ni
        // se instancio" de "se instancio pero petó al pasar a primer plano":
        // en la prueba del 05/09/2026 hubo 4 llamadas a start() y CERO lineas
        // de arranque, y sin esta traza no se sabia en cual de los dos casos
        // estabamos.
        CarLog.log(this, "DRIVE", "onStartCommand: entrando en arrancarDeVerdad")
        try {
            flagFile(this).writeText("1")
            CarLog.log(this, "DRIVE", "driving.flag escrito en " + flagFile(this).absolutePath)
        } catch (e: Exception) {
            CarLog.log(this, "DRIVE", "no se pudo escribir driving.flag: " + e.toString())
        }
        crearCanalSiHaceFalta()
        // ServiceCompat.startForeground gestiona sola la diferencia entre
        // versiones de Android: en API < 29 ignora el tipo (no existe alli),
        // y en API >= 34 lo exige para que coincida con el manifest o el
        // sistema lanza MissingForegroundServiceTypeException en caliente.
        // Envuelto a proposito: en Android 12+ arrancar un foreground service
        // desde segundo plano lanza ForegroundServiceStartNotAllowedException,
        // y un receptor de Bluetooth NO esta en la lista de excepciones. Es la
        // hipotesis principal del fallo del 05/09/2026, pero sin capturar la
        // excepcion real no se puede confirmar ni descartar: hasta ahora
        // moria en silencio y el log no decia absolutamente nada.
        try {
            ServiceCompat.startForeground(
                this, NOTIF_ID, construirNotificacion(),
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
            CarLog.log(this, "DRIVE", "startForeground OK")
        } catch (e: Throwable) {
            // Throwable y no Exception: ForegroundServiceStartNotAllowedException
            // hereda de IllegalStateException, pero si algun dia el sistema
            // lanza un Error en vez de una Exception tambien queremos verlo.
            CarLog.log(this, "DRIVE", "startForeground FALLO: " + e.javaClass.simpleName +
                " -> " + e.toString())
            try {
                val f = flagFile(this)
                if (f.exists()) f.delete()
            } catch (_: Exception) {}
            stopSelf()
            return
        }
        // El primer disparo de la cadena de sondeo NO se hace desde aqui.
        // Intentar reencadenar el Worker interno del plugin "workmanager"
        // desde Kotlin puro no compilaba (ese Worker es una clase privada
        // del plugin, no accesible desde este modulo) y anadir una segunda
        // via de disparo distinta a la que usa el resto de la app habria
        // sido mas fragil que sencillo. En su lugar: el propio Dart, la
        // proxima vez que backgroundCallbackDispatcher se ejecute por
        // cualquier via (incluida la periodica normal de 15 min, o el
        // primer arranque de la app), comprueba el flag y si esta activo
        // arranca la cadena de 90s el mismo. El margen realista hasta que
        // eso ocurra es de segundos si la app esta abierta cuando se
        // conecta el coche, y como mucho el resto del ciclo de 15 min si
        // no lo esta -- peor que un disparo instantaneo, pero sin el
        // riesgo de una integracion nativa con el Worker interno del plugin.
        CarLog.log(this, "DRIVE", "servicio arrancado, flag escrito")
    }

    private fun pararDeVerdad() {
        try {
            val f = flagFile(this)
            if (f.exists()) f.delete()
        } catch (e: Exception) {
            CarLog.log(this, "DRIVE", "no se pudo borrar driving.flag: " + e.toString())
        }
        CarLog.log(this, "DRIVE", "servicio parado")
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun crearCanalSiHaceFalta() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val es = Locale.getDefault().language == "es"
            val nm = getSystemService(NotificationManager::class.java)
            val ch = NotificationChannel(
                CHANNEL_ID,
                if (es) "Registro de trayecto" else "Trip recording",
                NotificationManager.IMPORTANCE_LOW
            )
            nm.createNotificationChannel(ch)
        }
    }

    private fun construirNotificacion(): Notification {
        val es = Locale.getDefault().language == "es"
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("LMB10")
            .setContentText(if (es) "Registrando tu trayecto" else "Recording your trip")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
}
