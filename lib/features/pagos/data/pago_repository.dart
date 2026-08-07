import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/pago_model.dart';

class PagoRepository {
  final _col = FirebaseFirestore.instance.collection('pagos');

  Query<Map<String, dynamic>> _conRango({DateTime? inicio, DateTime? fin, String? cobradorUid}) {
    Query<Map<String, dynamic>> query = _col;
    if (inicio != null) {
      query = query.where('fechaPago', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio));
    }
    if (fin != null) {
      final finInclusive = DateTime(fin.year, fin.month, fin.day, 23, 59, 59);
      query = query.where('fechaPago', isLessThanOrEqualTo: Timestamp.fromDate(finInclusive));
    }
    if (cobradorUid != null) {
      query = query.where('registradoPor', isEqualTo: cobradorUid);
    }
    return query;
  }

  /// Pagos en un rango de fechas (Dashboard, Reporte de Cobros). Sin
  /// rango trae los ultimos 200 para no descargar el historico entero.
  Future<List<PagoModel>> obtenerConRango({
    DateTime? inicio,
    DateTime? fin,
    String? cobradorUid,
  }) async {
    var query = _conRango(inicio: inicio, fin: fin, cobradorUid: cobradorUid);
    if (inicio == null && fin == null) {
      query = query.orderBy('fechaPago', descending: true).limit(200);
    }
    final snap = await query.get();
    final pagos = <PagoModel>[];
    for (final doc in snap.docs) {
      try {
        pagos.add(PagoModel.fromDoc(doc));
      } catch (_) {
        // documento con formato inesperado: se omite.
      }
    }
    pagos.sort((a, b) => (b.fechaPago?.compareTo(a.fechaPago ?? b.fechaPago!) ?? 0));
    return pagos;
  }

  Future<List<PagoModel>> obtenerPorPrestamo(String prestamoId) async {
    final snap = await _col.where('prestamoId', isEqualTo: prestamoId).get();
    final pagos = <PagoModel>[];
    for (final doc in snap.docs) {
      try {
        pagos.add(PagoModel.fromDoc(doc));
      } catch (_) {
        // documento con formato inesperado: se omite.
      }
    }
    pagos.sort((a, b) => (b.fechaPago?.compareTo(a.fechaPago ?? b.fechaPago!) ?? 0));
    return pagos;
  }

  /// Borra un pago Y revierte su efecto en el prestamo (montoPagado,
  /// mora, saldo), para que el saldo pendiente vuelva a ser el correcto
  /// despues de borrar -- si solo se borrara el doc de `pagos`, el
  /// prestamo seguiria mostrando ese abono como aplicado aunque el
  /// registro ya no exista.
  Future<void> eliminarConReversion(PagoModel pago) async {
    final db = FirebaseFirestore.instance;
    final prestamoRef = db.collection('prestamos').doc(pago.prestamoId);
    final pagoRef = _col.doc(pago.docId);

    await db.runTransaction((tx) async {
      final prestamoSnap = await tx.get(prestamoRef);
      if (prestamoSnap.exists) {
        final d = prestamoSnap.data()!;
        final montoPagadoActual = (d['montoPagado'] as num?)?.toDouble() ?? 0;
        final moraActual = (d['mora'] as num?)?.toDouble() ?? 0;
        final saldoActual = (d['saldo'] as num?)?.toDouble() ?? 0;
        final estadoActual = (d['estado'] ?? '') as String;

        final nuevoMontoPagado = (montoPagadoActual - pago.monto).clamp(0, double.infinity);
        final nuevaMora = moraActual + pago.mora;
        final nuevoSaldo = saldoActual + pago.monto + pago.mora;
        final nuevoEstado = nuevoSaldo <= 0.01
            ? 'saldado'
            : (nuevaMora > 0.01 ? 'mora' : (estadoActual == 'saldado' ? 'activo' : estadoActual));

        tx.update(prestamoRef, {
          'montoPagado': nuevoMontoPagado,
          'mora': nuevaMora,
          'saldo': nuevoSaldo,
          'estado': nuevoEstado,
        });
      }
      tx.delete(pagoRef);
    });
  }
}
