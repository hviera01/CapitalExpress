import 'package:cloud_firestore/cloud_firestore.dart';

/// Algunos documentos viejos de la app Kotlin guardaron campos de fecha
/// como milisegundos (int) en vez de Timestamp de Firestore (probable
/// `System.currentTimeMillis()` en algun flujo antiguo, en vez de
/// `Timestamp.now()`/`FieldValue.serverTimestamp()`). Un `as Timestamp?`
/// directo revienta con esos documentos reales y tumba toda la lista.
/// Esto acepta ambos formatos sin perder el dato.
Timestamp? asTimestamp(dynamic valor) {
  if (valor is Timestamp) return valor;
  if (valor is int) return Timestamp.fromMillisecondsSinceEpoch(valor);
  return null;
}
