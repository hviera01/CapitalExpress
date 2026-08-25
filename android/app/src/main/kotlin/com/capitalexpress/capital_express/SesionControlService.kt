package com.capitalexpress.capital_express

import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder

// Service "vacio" (no foreground, sin notificacion) cuyo unico
// proposito es recibir onTaskRemoved -- ese callback SOLO existe en
// Service, no en Activity (Android no avisa a las Activities cuando
// se quita la app de "recientes"). Se arranca una vez desde
// MainActivity.onCreate y se queda vivo en segundo plano mientras el
// sistema lo permita.
class SesionControlService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onTaskRemoved(rootIntent: Intent?) {
        val prefs = getSharedPreferences(PREFS_SESION, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(CLAVE_FORZAR_CIERRE, true).apply()
        super.onTaskRemoved(rootIntent)
        stopSelf()
    }
}
