package com.txurtxil.lpb10

import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import java.io.File

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
 *  Limitacion conocida: reacciona a CUALQUIER Bluetooth, tambien unos cascos.
 *  Filtrar por el dispositivo del coche es el paso siguiente, pendiente.
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
                } catch (e: Exception) {
                    CarLog.log(ctx, "BT", "no se pudo escribir driving.flag: " + e.toString())
                }
            } else if (habiaAntes && !hayAhora) {
                try {
                    val f = flagFile(ctx)
                    if (f.exists()) f.delete()
                    CarLog.log(ctx, "BT", "driving.flag QUITADO")
                } catch (e: Exception) {
                    CarLog.log(ctx, "BT", "no se pudo borrar driving.flag: " + e.toString())
                }
            }
        } catch (e: Exception) {
            try { CarLog.log(ctx, "BT", "excepcion en onReceive: " + e.toString()) } catch (_: Exception) {}
        }
    }
}
