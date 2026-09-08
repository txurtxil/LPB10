package com.txurtxil.lpb10

import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "lmb10/rawbt"
    private val rawbtPackage = "ru.a402d.rawbtprinter"
    private val btChannel = "lmb10/btcar"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                if (call.method == "printRawBT") {
                    val text = call.argument<String>("text") ?: ""
                    result.success(sendToRawBT(text))
                } else {
                    result.notImplemented()
                }
            }
        // Deja que la pantalla de Ajustes muestre los dispositivos ya
        // emparejados (Bluetooth del sistema) para que el usuario marque
        // cuales son el coche. CarBtReceiver usa esa misma lista para
        // ignorar el resto (auriculares, reloj...).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, btChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "listPaired" -> result.success(listPairedDevices())
                    "getCarMacs" -> result.success(CarBtConfig.carMacs(this).toList())
                    "setCarMacs" -> {
                        @Suppress("UNCHECKED_CAST")
                        val macs = (call.argument<List<String>>("macs") ?: emptyList())
                            .toSet()
                        CarBtConfig.setCarMacs(this, macs)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** Emparejados, no solo conectados ahora mismo: el TCU/audio del coche
     *  suele aparecer aqui aunque el usuario abra esta pantalla con el motor
     *  parado. Requiere BLUETOOTH_CONNECT (ya declarado en el manifest para
     *  CarBtReceiver); si el usuario todavia no lo ha concedido, se devuelve
     *  vacio en vez de tumbar la pantalla. */
    private fun listPairedDevices(): List<Map<String, String>> {
        return try {
            val manager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
            val adapter = manager?.adapter ?: return emptyList()
            adapter.bondedDevices.map { d ->
                val nombre = try { d.name } catch (e: SecurityException) { null } ?: "?"
                mapOf("mac" to d.address, "nombre" to nombre)
            }
        } catch (e: SecurityException) {
            emptyList()
        }
    }

    private fun sendToRawBT(text: String): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                setPackage(rawbtPackage)
                putExtra(Intent.EXTRA_TEXT, text)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }
}
