package com.txurtxil.lpb10

import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequest
import androidx.work.WorkManager
import dev.fluttercommunity.workmanager.BackgroundWorker
import java.io.File
import java.util.concurrent.TimeUnit

/** Marca en un fichero-flag si el movil esta conectado a algun Bluetooth.
 *
 *  Por que quedo asi de simple: al principio esto arrancaba un foreground
 *  service (CarDriveService) para mantener vivo el sondeo cada 90s durante la
 *  conduccion. Google Play exige declarar ese tipo de servicio con un video de
 *  demostracion y revision manual, asi que el servicio se retiro entero el
 *  05/09/2026. Ahora esto solo pone o quita el flag, y es el lado Dart quien
 *  arranca la cadena de sondeo cuando lo ve puesto.
 *
 *  Confirmado el 04-05/09/2026 con datos reales:
 *   - El broadcast SI llega con la app dormida, siempre que "Dispositivos
 *     cercanos" este concedido. Sin ese permiso Android no entrega nada.
 *   - El coche expone DOS conexiones simultaneas (TCU + audio), por eso se
 *     cuenta cuantas hay en vez de mirar una MAC fija.
 *
 *  Filtrado por MAC (07/09/2026): antes reaccionaba a CUALQUIER Bluetooth,
 *  tambien unos cascos o el reloj. Ahora, si el usuario ha marcado en
 *  Ajustes que dispositivos son el coche (CarBtConfig), se ignora cualquier
 *  MAC que no este en esa lista. Si la lista esta vacia (nadie la ha
 *  configurado todavia) se mantiene el comportamiento antiguo para no dejar
 *  a nadie sin deteccion de conduccion de un dia para otro.
 *
 *  Arranque inmediato del sondeo (12/09/2026): al ponerse el flag se encola
 *  desde aqui la primera tarea de sondeo de conduccion. Antes dependia de
 *  que el ciclo periodico de ~15 min de WorkManager cayera DENTRO del
 *  trayecto: si no caia, no se sondeaba ni una vez y la ruta salia
 *  "reconstruida" (sin mapa ni duracion). Caso real del 12/09/2026: dos
 *  trayectos de 6 y 11 km con CERO puntos de sondeo.
 */
class CarBtReceiver : BroadcastReceiver() {
    companion object {
        private const val PREFS = "lmb10_bt"
        private const val KEY_CONECTADOS = "connected_macs"

        /** Misma carpeta que carlog.txt. Dart la resuelve con
         *  getApplicationDocumentsDirectory(), que en Android apunta aqui.
         *  Verificado en el log del 05/09/2026: la ruta que escribio el
         *  servicio y la que lee Dart coinciden. */
        private fun flagFile(ctx: Context): File {
            val docs = File(ctx.filesDir.parentFile, "app_flutter/lmb10_history")
            docs.mkdirs()
            return File(docs, "driving.flag")
        }
    }

    override fun onReceive(ctx: Context, intent: Intent) {
        try {
            val conectando = when (intent.action) {
                BluetoothDevice.ACTION_ACL_CONNECTED -> true
                BluetoothDevice.ACTION_ACL_DISCONNECTED -> false
                else -> return
            }
            @Suppress("DEPRECATION")
            val dev = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
            val mac = try { dev?.address } catch (e: SecurityException) { null } ?: "desconocido"
            val nombre = try { dev?.name } catch (e: SecurityException) { null } ?: "?"

            val configuradas = CarBtConfig.carMacs(ctx)
            if (configuradas.isNotEmpty() && mac !in configuradas) {
                CarLog.log(ctx, "BT", "ignorado (no es el coche): mac=$mac nombre=$nombre")
                return
            }

            val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val actuales = HashSet(prefs.getStringSet(KEY_CONECTADOS, emptySet()) ?: emptySet())
            val habiaAntes = actuales.isNotEmpty()
            if (conectando) actuales.add(mac) else actuales.remove(mac)
            prefs.edit().putStringSet(KEY_CONECTADOS, actuales).apply()
            val hayAhora = actuales.isNotEmpty()

            CarLog.log(ctx, "BT", (if (conectando) "CONECTADO" else "DESCONECTADO") +
                " mac=$mac nombre=$nombre  (conectados tras esto: ${actuales.size})")

            if (!habiaAntes && hayAhora) {
                try {
                    flagFile(ctx).writeText("1")
                    CarLog.log(ctx, "BT", "driving.flag PUESTO")
                    CarDriveEvents.log(ctx, "connect")
                    encolarSondeoConduccion(ctx)
                } catch (e: Exception) {
                    CarLog.log(ctx, "BT", "no se pudo escribir driving.flag: " + e.toString())
                }
            } else if (habiaAntes && !hayAhora) {
                try {
                    val f = flagFile(ctx)
                    if (f.exists()) f.delete()
                    CarLog.log(ctx, "BT", "driving.flag QUITADO")
                    CarDriveEvents.log(ctx, "disconnect")
                } catch (e: Exception) {
                    CarLog.log(ctx, "BT", "no se pudo borrar driving.flag: " + e.toString())
                }
            }
        } catch (e: Exception) {
            try { CarLog.log(ctx, "BT", "excepcion en onReceive: " + e.toString()) } catch (_: Exception) {}
        }
    }

    /** Encola la primera tarea de sondeo de conduccion nada mas conectar el
     *  Bluetooth del coche, sin esperar al ciclo periodico de WorkManager.
     *
     *  La peticion es identica a la que encola el lado Dart
     *  (registerOneOffTask en main.dart): mismo worker del plugin
     *  (BackgroundWorker), misma clave de tarea (DART_TASK_KEY), mismo
     *  nombre unico ("lm_drive_poll") y politica KEEP para no molestar a
     *  una cadena ya en marcha (si hay una tarea pendiente, esta se
     *  descarta). Cuando se ejecuta, backgroundCallbackDispatcher la
     *  reconoce como kDrivePollTaskName y reencadena cada 90s mientras
     *  driving.flag exista; si el coche ya se ha desconectado, la cadena
     *  muere en la primera pasada. El arranque por ciclo periodico se
     *  mantiene como respaldo.
     *
     *  OJO al actualizar el plugin workmanager: BackgroundWorker y
     *  DART_TASK_KEY son internos del plugin (verificados en
     *  workmanager_android 0.9.0+2). Si cambian, este encolado dejaria de
     *  arrancar la cadena (sin romper nada mas: quedaria el respaldo del
     *  ciclo periodico). */
    private fun encolarSondeoConduccion(ctx: Context) {
        try {
            val datos = Data.Builder()
                .putString(BackgroundWorker.DART_TASK_KEY, "lmDrivePollTask")
                .build()
            val req = OneTimeWorkRequest.Builder(BackgroundWorker::class.java)
                .setInputData(datos)
                .setInitialDelay(0, TimeUnit.SECONDS)
                .build()
            WorkManager.getInstance(ctx).enqueueUniqueWork(
                "lm_drive_poll",
                ExistingWorkPolicy.KEEP,
                req,
            )
            CarLog.log(ctx, "BT", "DRIVE-KICK sondeo encolado al conectar")
        } catch (e: Exception) {
            CarLog.log(ctx, "BT", "DRIVE-KICK fallo al encolar: " + e.toString())
        }
    }
}
