package com.txurtxil.lpb10

import android.Manifest
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.core.app.ActivityCompat

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
                    "ensureBtPermission" -> requestBtConnect(result)
                    "connectedDevices" -> connectedBtDevices(result)
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

    private var pendingBtPermission: MethodChannel.Result? = null

    /// Pide BLUETOOTH_CONNECT en runtime (v3.60.194). Se invoca desde la
    /// pantalla Bluetooth del coche, con contexto para el usuario. Si ya
    /// estaba concedido, responde true sin molestar.
    private fun requestBtConnect(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 31) { result.success(true); return }
        if (checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) ==
            PackageManager.PERMISSION_GRANTED) { result.success(true); return }
        pendingBtPermission = result
        ActivityCompat.requestPermissions(this,
            arrayOf(Manifest.permission.BLUETOOTH_CONNECT), 4242)
    }

    override fun onRequestPermissionsResult(requestCode: Int,
        permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 4242) {
            val ok = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingBtPermission?.success(ok)
            pendingBtPermission = null
        }
    }

    /// MACs conectadas AHORA (perfiles HEADSET y A2DP: TCU + audio del
    /// coche). Con timeout de 1,5 s: si un proxy tarda, se responde con lo
    /// que haya. Sin esto, auto-marcar el coche seria adivinar.
    private fun connectedBtDevices(result: MethodChannel.Result) {
        val manager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val adapter = manager?.adapter
        if (adapter == null || !adapter.isEnabled) {
            result.success(emptyList<String>()); return
        }
        val found = mutableSetOf<String>()
        val proxies = mutableListOf<Pair<Int, BluetoothProfile>>()
        val perfiles = intArrayOf(BluetoothProfile.HEADSET, BluetoothProfile.A2DP)
        var respondido = false
        var pendientes = perfiles.size
        fun responder() {
            if (respondido) return
            respondido = true
            proxies.forEach { (p, pr) -> try { adapter.closeProfileProxy(p, pr) } catch (_: Exception) {} }
            runOnUiThread { result.success(found.toList()) }
        }
        val listener = object : BluetoothProfile.ServiceListener {
            override fun onServiceConnected(profile: Int, proxy: BluetoothProfile) {
                proxies.add(profile to proxy)
                try {
                    proxy.connectedDevices.forEach { found.add(it.address) }
                } catch (_: SecurityException) {}
                if (--pendientes <= 0) responder()
            }
            override fun onServiceDisconnected(profile: Int) {}
        }
        perfiles.forEach { adapter.getProfileProxy(this, listener, it) }
        Handler(Looper.getMainLooper()).postDelayed({ responder() }, 1500)
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
