package com.txurtxil.lpb10

import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** PASO 1 de la deteccion de conduccion por Bluetooth: SOLO observa y anota.
 *
 *  No arranca ningun servicio ni altera el comportamiento de la app. Existe
 *  para responder con datos, y no por suposicion, a dos preguntas:
 *
 *    1. Si ACL_CONNECTED llega de verdad a un receptor del manifest con la
 *       app dormida en segundo plano. Se cree que estos broadcasts estan
 *       exentos de las restricciones de Android 8+, pero no se da por hecho.
 *    2. Cual es la MAC con la que el movil empareja con el coche. La API del
 *       vehiculo reporta una (bluetoothAddr), pero puede ser la del TCU y no
 *       la del equipo de audio con el que empareja el telefono.
 *
 *  Todo va envuelto en try/catch: en Android 12+ leer nombre y MAC exige el
 *  permiso BLUETOOTH_CONNECT, que es de ejecucion. Si salta SecurityException
 *  tambien es informacion util, asi que se registra en vez de tragarsela.
 */
class CarBtReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        try {
            val accion = when (intent.action) {
                BluetoothDevice.ACTION_ACL_CONNECTED -> "CONECTADO"
                BluetoothDevice.ACTION_ACL_DISCONNECTED -> "DESCONECTADO"
                else -> return
            }
            @Suppress("DEPRECATION")
            val dev = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
            val mac = try {
                dev?.address ?: "nulo"
            } catch (e: SecurityException) {
                "sin permiso BLUETOOTH_CONNECT"
            }
            val nombre = try {
                dev?.name ?: "nulo"
            } catch (e: SecurityException) {
                "sin permiso BLUETOOTH_CONNECT"
            }
            CarLog.log(ctx, "BT", "$accion mac=$mac nombre=$nombre")
        } catch (e: Exception) {
            try {
                CarLog.log(ctx, "BT", "excepcion en onReceive: " + e.toString())
            } catch (_: Exception) {}
        }
    }
}
