import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/prestamo_model.dart';

/// Mismo criterio que estadoEfectivo() en HistorialPrestamosScreen.kt:
/// reconcilia el campo `estado` contra saldo/proximoPago en vez de
/// confiar ciegamente en el texto guardado.
String estadoEfectivoPrestamo(PrestamoModel p) {
  if (p.saldo <= 0.01 || p.estado == 'saldado' || p.estado == 'completado') {
    return 'saldado';
  }
  final proximoPago = p.proximoPago;
  if (proximoPago is Timestamp && proximoPago.toDate().isBefore(DateTime.now())) {
    return 'vencido';
  }
  return p.estado.isEmpty ? 'activo' : p.estado;
}
