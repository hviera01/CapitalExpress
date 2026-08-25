package com.capitalexpress.capital_express

import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

const val CANAL_SESION = "capitalexpress/sesion"
const val PREFS_SESION = "capitalexpress_sesion_control"
const val CLAVE_FORZAR_CIERRE = "forzar_cierre"

// FlutterFragmentActivity (no FlutterActivity) porque el plugin
// local_auth lo requiere para el prompt de huella/Face ID.
class MainActivity : FlutterFragmentActivity() {

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // Arranca el service "centinela" que detecta cuando se quita
        // la app de la multitarea -- ver SesionControlService, ese
        // callback (onTaskRemoved) SOLO existe en Service, no en
        // Activity.
        startService(Intent(this, SesionControlService::class.java))
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CANAL_SESION).setMethodCallHandler { call, result ->
            when (call.method) {
                // Dart lo llama al arrancar, ANTES de restaurar la sesion
                // guardada -- si esto da true, la app fue quitada de la
                // multitarea la ultima vez y hay que cerrar sesion de una.
                "consumirCierreForzado" -> {
                    val prefs = getSharedPreferences(PREFS_SESION, Context.MODE_PRIVATE)
                    val forzado = prefs.getBoolean(CLAVE_FORZAR_CIERRE, false)
                    if (forzado) prefs.edit().putBoolean(CLAVE_FORZAR_CIERRE, false).apply()
                    result.success(forzado)
                }
                else -> result.notImplemented()
            }
        }
    }
}
