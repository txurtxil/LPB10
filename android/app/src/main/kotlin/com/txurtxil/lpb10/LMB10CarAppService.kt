package com.txurtxil.lpb10

import android.content.Intent
import androidx.car.app.CarAppService
import androidx.car.app.Screen
import androidx.car.app.Session
import androidx.car.app.validation.HostValidator

open class LMB10CarAppService : CarAppService() {
    override fun createHostValidator(): HostValidator =
        if (applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE != 0) {
            HostValidator.ALLOW_ALL_HOSTS_VALIDATOR
        } else {
            HostValidator.Builder(applicationContext)
                .addAllowedHosts(androidx.car.app.R.array.hosts_allowlist_sample)
                .build()
        }

    override fun onCreate() {
        super.onCreate()
        // Arranca el motor Dart cuanto antes: tarda 1-2 s y la cola
        // absorbe cualquier toque anterior a que este listo.
        CarLog.log(this, "SERVICE", this.javaClass.simpleName + " onCreate")
        CarBridge.start(this)
    }

    override fun onCreateSession(): Session = object : Session() {
        override fun onCreateScreen(intent: Intent): Screen {
            CarLog.log(carContext, "SERVICE",
                "onCreateScreen action=" + intent.action + " data=" + intent.data)
            return CarMainScreen(carContext)
        }

        // Cuando el host entrega un intent a una sesion YA VIVA no llama a
        // onCreateScreen: llama aqui. Si startCarApp(ACTION_NAVIGATE) nos lo
        // devuelve a nosotros mismos por ser categoria NAVIGATION, la traza
        // sale por aqui y en ningun otro sitio.
        override fun onNewIntent(intent: Intent) {
            CarLog.log(carContext, "SERVICE",
                "onNewIntent action=" + intent.action + " data=" + intent.data)
        }
    }
}
