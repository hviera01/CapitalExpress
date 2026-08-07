import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/prestamo_model.dart';

class PrestamoRepository {
  final _db = FirebaseFirestore.instance;
  final _col = FirebaseFirestore.instance.collection('prestamos');
  final _contadorRef =
      FirebaseFirestore.instance.collection('configuracion').doc('contadorPrestamos');

  /// Mismo formato que PrestamoNumberHelper.kt: [Iniciales]-[00001].
  String _inicialesCliente(String nombreCompleto) {
    final palabras = nombreCompleto.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (palabras.isEmpty) return 'CLI';
    if (palabras.length == 1) {
      return palabras[0].substring(0, palabras[0].length.clamp(0, 3)).toUpperCase();
    }
    if (palabras.length == 2) {
      return (palabras[0][0] + palabras[1].substring(0, palabras[1].length.clamp(0, 2)))
          .toUpperCase();
    }
    return (palabras[0][0] + palabras[1][0] + palabras[2][0]).toUpperCase();
  }

  Future<String> generarNumeroPrestamo(String clienteNombre) async {
    final iniciales = _inicialesCliente(clienteNombre);

    final siguiente = await _db.runTransaction<int>((tx) async {
      final snap = await tx.get(_contadorRef);
      final actual = snap.exists ? ((snap.data()?['ultimoNumero'] as num?)?.toInt() ?? 0) : 0;
      final nuevo = actual + 1;
      tx.set(_contadorRef, {'ultimoNumero': nuevo});
      return nuevo;
    });

    final numeroFormateado = siguiente.toString().padLeft(5, '0');
    return '$iniciales-$numeroFormateado';
  }

  /// Admin ve todos; cobrador solo los suyos (`cobradorAsignado == uid`).
  /// `incluirEliminados` replica el toggle "Ver eliminados" de PrestamosAdmin.kt.
  Stream<List<PrestamoModel>> streamPrestamos({
    String? cobradorUid,
    bool incluirEliminados = false,
  }) {
    Query<Map<String, dynamic>> query = _col;
    if (cobradorUid != null) {
      query = query.where('cobradorAsignado', isEqualTo: cobradorUid);
    }
    return query.snapshots().map((snap) {
      final prestamos = <PrestamoModel>[];
      for (final doc in snap.docs) {
        try {
          final p = PrestamoModel.fromDoc(doc);
          if (p.eliminado && !incluirEliminados) continue;
          prestamos.add(p);
        } catch (_) {
          // documento con un campo en formato inesperado: se omite, no
          // debe tumbar el resto de la lista (mismo criterio que clientes).
        }
      }
      prestamos.sort((a, b) => (b.fechaCreacion?.compareTo(a.fechaCreacion ?? b.fechaCreacion!) ?? 0));
      return prestamos;
    });
  }

  Future<PrestamoModel?> obtenerPorId(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return PrestamoModel.fromDoc(doc);
  }

  Future<String> crear(Map<String, dynamic> datos) async {
    final docRef = _col.doc();
    await docRef.set({
      ...datos,
      'id': docRef.id,
      'prestamoId': docRef.id,
      'fechaCreacion': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<void> marcarEliminado(String id, {required String eliminadoPor}) async {
    await _col.doc(id).update({
      'eliminado': true,
      'eliminadoPor': eliminadoPor,
      'fechaUltimaActualizacion': FieldValue.serverTimestamp(),
    });
  }

  Future<void> restaurar(String id) async {
    await _col.doc(id).update({
      'eliminado': false,
      'eliminadoPor': FieldValue.delete(),
      'fechaUltimaActualizacion': FieldValue.serverTimestamp(),
    });
  }
}
