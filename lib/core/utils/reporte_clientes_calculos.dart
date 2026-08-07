import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/prestamo_model.dart';

/// Mismas formulas que ReporteClienteScreen.kt (estadoEfectivo,
/// totalesCliente, proximoPagoCliente) portadas literal para que el
/// "pendiente"/"saldo" que ve el usuario sea siempre el mismo numero,
/// lo mire desde donde lo mire (Resumen de Cliente, este reporte, y
/// cualquier pantalla futura que toque el mismo calculo).
class TotalesCliente {
  final double prestado;
  final double abonado;
  final double pendiente;

  const TotalesCliente({this.prestado = 0, this.abonado = 0, this.pendiente = 0});
}

double _prestadoDe(PrestamoModel p) => p.totalPagar > 0 ? p.totalPagar : (p.monto + p.interes);

TotalesCliente totalesCliente(List<PrestamoModel> prestamos) {
  var prestado = 0.0, abonado = 0.0, pendiente = 0.0;
  for (final p in prestamos) {
    final total = _prestadoDe(p);
    prestado += total;
    abonado += p.montoPagado;
    pendiente += (total - p.montoPagado).clamp(0, double.infinity);
  }
  return TotalesCliente(prestado: prestado, abonado: abonado, pendiente: pendiente);
}

/// 'saldado' si no le queda nada pendiente en ningun prestamo (o el
/// cliente esta marcado saldado a mano), 'inactivo' si esta desactivado,
/// 'activo' en cualquier otro caso.
String estadoEfectivoCliente({
  required String estadoCliente,
  required List<PrestamoModel> prestamos,
}) {
  final todosSaldados = prestamos.isNotEmpty &&
      prestamos.every((p) {
        final total = _prestadoDe(p);
        final pagado = p.montoPagado;
        return (total - pagado) <= 0.01 ||
            p.estado.toLowerCase() == 'saldado' ||
            p.estado.toLowerCase() == 'completado';
      });

  if (todosSaldados || estadoCliente.toLowerCase() == 'saldado') return 'saldado';
  if (estadoCliente.toLowerCase() == 'inactivo') return 'inactivo';
  return 'activo';
}

DateTime? proximoPagoCliente(List<PrestamoModel> prestamos) {
  final hoy = DateTime.now();
  final fechas = prestamos
      .where((p) => p.saldo > 0.01 && p.proximoPago is Timestamp)
      .map((p) => (p.proximoPago as Timestamp).toDate())
      .toList();
  if (fechas.isEmpty) return null;

  final futuras = fechas.where((f) => !f.isBefore(hoy)).toList();
  if (futuras.isNotEmpty) {
    futuras.sort();
    return futuras.first;
  }
  fechas.sort();
  return fechas.first;
}
