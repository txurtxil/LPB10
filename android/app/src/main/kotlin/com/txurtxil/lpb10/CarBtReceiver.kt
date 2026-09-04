package com.txurtxil.lpb10

import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Arranca/para CarDriveService segun haya o no algun dispositivo Bluetooth
 *  conectado. Ampliacion del observador del paso 1 (ver backup con fecha):
 *  ese paso confirmo el 04/09/2026, con datos reales, que:
 *   - El broadcast SI llega con la app dormida, siempre que el permiso
 *     "Dispositivos cercanos" este concedido (si no, Android no lo entrega).
 *   - El coche expone DOS conexiones Bluetooth simultaneas (TCU + audio),
 *     no una. Por eso aqui se lleva la cuenta de CUANTAS hay conectadas en
 *     vez de mirar una unica MAC fija: se arranca con la primera y se para
 *     solo cuando la ultima se ha ido.
 *
 *  Limitacion conocida y asumida por ahora: esto reacciona a CUALQUIER
 *  Bluetooth (unos cascos tambien lo disparan), no solo al coche. Filtrar
 *  por el dispositivo correcto es el siguiente paso (que el usuario lo
 *  elija en Ajustes), pendiente de hacer.
 */
class CarBtReceiver : BroadcastReceiver() {
    companion object {
        private const val PREFS = "lmb10_bt"
        private const val KEY_CONECTADOS = "connected_macs"
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
                CarLog.log(ctx, "BT", "arrancando CarDriveService")
                CarDriveService.start(ctx)
            } else if (habiaAntes && !hayAhora) {
                CarLog.log(ctx, "BT", "parando CarDriveService")
                CarDriveService.stop(ctx)
            }
        } catch (e: Exception) {
            try { CarLog.log(ctx, "BT", "excepcion en onReceive: " + e.toString()) } catch (_: Exception) {}
        }
    }
}
