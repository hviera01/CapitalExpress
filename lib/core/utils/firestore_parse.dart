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

/// El campo `proximoPago` de un prestamo es historicamente inconsistente
/// en Firestore: Timestamp (escrituras nuevas), String "dd/MM/yyyy"
/// (formato que usaba el sistema Kotlin viejo en varios flujos), el
/// string literal "saldado", o int/millis. Antes se descartaba cualquier
/// prestamo cuyo campo no fuera EXACTAMENTE un Timestamp -- eso dejaba
/// fuera de Cobros/Notificaciones (y de "Proximo pago" en Reporte de
/// Clientes) prestamos enteros, sobre todo los mas viejos creados antes
/// de esta reescritura en Flutter que todavia tienen el formato string.
DateTime? asProximoPagoFecha(dynamic valor) {
  if (valor == null) return null;
  if (valor is Timestamp) return valor.toDate();
  if (valor is int) return DateTime.fromMillisecondsSinceEpoch(valor);
  if (valor is String) {
    final texto = valor.trim();
    if (texto.isEmpty || texto.toLowerCase() == 'saldado') return null;
    final match = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{2,4})').firstMatch(texto);
    if (match == null) return null;
    final dia = int.tryParse(match.group(1)!);
    final mes = int.tryParse(match.group(2)!);
    var anio = int.tryParse(match.group(3)!);
    if (dia == null || mes == null || anio == null) return null;
    if (anio < 100) anio += 2000;
    try {
      return DateTime(anio, mes, dia);
    } catch (_) {
      return null;
    }
  }
  return null;
}
