import '../models/prestamo_model.dart';
import 'firestore_parse.dart';

/// Mismo criterio que estadoEfectivo() en HistorialPrestamosScreen.kt:
/// reconcilia el campo `estado` contra saldo/proximoPago en vez de
/// confiar ciegamente en el texto guardado.
String estadoEfectivoPrestamo(PrestamoModel p) {
  if (p.saldo <= 0.01 || p.estado == 'saldado' || p.estado == 'completado') {
    return 'saldado';
  }
  final fecha = asProximoPagoFecha(p.proximoPago);
  if (fecha != null && fecha.isBefore(DateTime.now())) {
    return 'vencido';
  }
  return p.estado.isEmpty ? 'activo' : p.estado;
}
