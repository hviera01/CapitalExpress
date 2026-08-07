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

  Future<void> eliminar(String id) async {
    await _col.doc(id).delete();
  }
}
