import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Limite de espera por el servidor antes de intentar el cache local.
///
/// Sin esto, `.get()` de Firestore puede quedarse esperando una
/// respuesta del servidor por mucho mas tiempo del que el SDK tarda en
/// darse por vencido solo (variable, y en datos moviles con señal
/// debil puede sentirse "colgado" -- confirmado: pantalla de
/// desbloqueo sin reaccionar al tocar "Continuar", Historial de Pagos
/// y Cobros/Notificaciones tardando mucho en cargar). Con un limite
/// fijo y corto, si el servidor no contesta a tiempo se prueba el
/// cache (misma data que ya se vio la ultima vez que hubo conexion) en
/// vez de seguir esperando el mismo tiempo largo de siempre.
const tiempoLimiteFirestore = Duration(seconds: 8);

/// Version "rapida" de `query.get()`: si el servidor no contesta
/// dentro de [tiempoLimite], prueba el cache local. IMPORTANTE: si el
/// cache no tiene nada guardado para esta consulta (ej. primera vez
/// que se abre esta pantalla/rango en este dispositivo), NO se
/// devuelve ese resultado vacio como si fuera la respuesta real --
/// eso mostraria "no hay pagos"/"no hay cobros" estando mal, algo
/// mucho peor en una app de dinero que tardar un poco mas. En ese caso
/// se vuelve a esperar al servidor, sin limite de tiempo corto.
Future<QuerySnapshot<Map<String, dynamic>>> obtenerRapido(
  Query<Map<String, dynamic>> query, {
  Duration tiempoLimite = tiempoLimiteFirestore,
}) async {
  try {
    return await query.get().timeout(tiempoLimite);
  } on TimeoutException {
    try {
      final delCache = await query.get(const GetOptions(source: Source.cache));
      if (delCache.docs.isNotEmpty) return delCache;
    } catch (_) {
      // cache no disponible para esta consulta: se sigue abajo.
    }
    return query.get();
  }
}

/// Igual que [obtenerRapido] pero para leer un documento puntual.
Future<DocumentSnapshot<Map<String, dynamic>>> obtenerDocRapido(
  DocumentReference<Map<String, dynamic>> doc, {
  Duration tiempoLimite = tiempoLimiteFirestore,
}) async {
  try {
    return await doc.get().timeout(tiempoLimite);
  } on TimeoutException {
    try {
      final delCache = await doc.get(const GetOptions(source: Source.cache));
      if (delCache.exists) return delCache;
    } catch (_) {
      // cache no disponible para este documento: se sigue abajo.
    }
    return doc.get();
  }
}
