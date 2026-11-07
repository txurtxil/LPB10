package com.txurtxil.lpb10

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Motor Flutter headless para ejecutar comandos Dart (mTLS/HMAC) desde la
 * pantalla del coche. Mismo patron que el isolate de WorkManager.
 * Todo se despacha al main looper; la cola cubre el arranque del motor.
 */
object CarBridge {
    private const val CHANNEL = "lmb10/carapp"
    private var engine: FlutterEngine? = null
    private var channel: MethodChannel? = null
    private var ready = false
    private val queue = ArrayList<Pending>()

    private class Pending(
        val method: String,
        val args: Map<String, Any?>?,
        val cb: (Boolean) -> Unit
    )

    fun start(context: Context) {
        val appCtx = context.applicationContext
        main {
            if (engine != null) return@main
            try {
                val loader = FlutterInjector.instance().flutterLoader()
                loader.startInitialization(appCtx)
                loader.ensureInitializationComplete(appCtx, null)
                // FlutterEngine(Context) registra los plugins automaticamente.
                val e = FlutterEngine(appCtx)
                val entry = DartExecutor.DartEntrypoint(
                    loader.findAppBundlePath(), "carAppMain"
                )
                e.dartExecutor.executeDartEntrypoint(entry)
                val ch = MethodChannel(e.dartExecutor.binaryMessenger, CHANNEL)
                ch.setMethodCallHandler { call, result ->
                    if (call.method == "ready") {
                        ready = true
                        result.success(true)
                        drain()
                    } else {
                        result.notImplemented()
                    }
                }
                engine = e
                channel = ch
                CarLog.log(appCtx, "BRIDGE", "FlutterEngine arrancado")
            } catch (t: Throwable) {
                CarLog.log(appCtx, "BRIDGE", "ERROR motor: " + t.message)
                engine = null
                channel = null
                failAll()
            }
        }
    }

    fun invoke(method: String, args: Map<String, Any?>?, cb: (Boolean) -> Unit) {
        main {
            val ch = channel
            if (!ready || ch == null) {
                queue.add(Pending(method, args, cb))
                return@main
            }
            ch.invokeMethod(method, args, object : MethodChannel.Result {
                override fun success(r: Any?) { cb(r == true) }
                override fun error(c: String, m: String?, d: Any?) { cb(false) }
                override fun notImplemented() { cb(false) }
            })
        }
    }

    fun invokeStr(method: String, args: Map<String, Any?>?, cb: (String?) -> Unit) {
        main {
            val ch = channel
            if (!ready || ch == null) {
                queue.add(Pending(method, args) { ok -> cb(if (ok) "1/1" else "") })
                return@main
            }
            ch.invokeMethod(method, args, object : MethodChannel.Result {
                override fun success(r: Any?) { cb(r as? String) }
                override fun error(c: String, m: String?, d: Any?) { cb("") }
                override fun notImplemented() { cb("") }
            })
        }
    }

    private fun drain() {
        val pending = ArrayList(queue)
        queue.clear()
        for (p in pending) invoke(p.method, p.args, p.cb)
    }

    private fun failAll() {
        val pending = ArrayList(queue)
        queue.clear()
        for (p in pending) p.cb(false)
    }

    private fun main(block: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) block()
        else Handler(Looper.getMainLooper()).post(block)
    }
}
