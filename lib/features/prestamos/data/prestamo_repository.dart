import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/prestamo_model.dart';
import '../../../core/utils/normalizar_texto.dart';

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

  /// Trae TODOS los prestamos no eliminados del alcance (para el Reporte
  /// de Clientes, que necesita el universo completo -- no es para
  /// pantallas de navegacion cotidiana, ahi se usa `buscar`).
  Future<List<PrestamoModel>> obtenerTodos({String? cobradorUid}) async {
    Query<Map<String, dynamic>> query = _col.where('eliminado', isEqualTo: false);
    if (cobradorUid != null) {
      query = query.where('cobradorAsignado', isEqualTo: cobradorUid);
    }
    final snap = await query.get();
    final prestamos = <PrestamoModel>[];
    for (final doc in snap.docs) {
      try {
        prestamos.add(PrestamoModel.fromDoc(doc));
      } catch (_) {
        // documento con formato inesperado: se omite.
      }
    }
    return prestamos;
  }

  /// Cantidad total de prestamos del alcance dado (para el stat "Total"
  /// sin tener que bajar todos los documentos).
  Future<int> contar({String? cobradorUid, bool soloEliminados = false}) async {
    Query<Map<String, dynamic>> query = _col.where('eliminado', isEqualTo: soloEliminados);
    if (cobradorUid != null) {
      query = query.where('cobradorAsignado', isEqualTo: cobradorUid);
    }
    final agg = await query.count().get();
    return agg.count ?? 0;
  }

  Future<int> contarPorEstado(String estado, {String? cobradorUid}) async {
    Query<Map<String, dynamic>> query =
        _col.where('estado', isEqualTo: estado).where('eliminado', isEqualTo: false);
    if (cobradorUid != null) {
      query = query.where('cobradorAsignado', isEqualTo: cobradorUid);
    }
    final agg = await query.count().get();
    return agg.count ?? 0;
  }

  /// Busqueda puntual (no streaming), igual criterio que
  /// ClienteRepository.buscar: filtra por cobrador/estado/eliminado en
  /// el servidor y el texto libre en memoria sobre ese subconjunto.
  Future<List<PrestamoModel>> buscar({
    String? cobradorUid,
    String? estado,
    bool incluirEliminados = false,
    String texto = '',
  }) async {
    Query<Map<String, dynamic>> query = _col.where('eliminado', isEqualTo: incluirEliminados);
    if (cobradorUid != null) {
      query = query.where('cobradorAsignado', isEqualTo: cobradorUid);
    }
    if (estado != null) {
      query = query.where('estado', isEqualTo: estado);
    }

    final snap = await query.limit(100).get();
    final prestamos = <PrestamoModel>[];
    for (final doc in snap.docs) {
      try {
        prestamos.add(PrestamoModel.fromDoc(doc));
      } catch (_) {
        // documento con formato inesperado: se omite.
      }
    }
    prestamos.sort((a, b) => (b.fechaCreacion?.compareTo(a.fechaCreacion ?? b.fechaCreacion!) ?? 0));

    if (texto.trim().isEmpty) return prestamos;
    final q = normalizarTexto(texto);
    return prestamos
        .where((p) =>
            normalizarTexto(p.cliente).contains(q) || normalizarTexto(p.numeroPrestamo).contains(q))
        .toList();
  }

  Future<PrestamoModel?> obtenerPorId(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return PrestamoModel.fromDoc(doc);
  }

  /// Prestamos de un cliente puntual (para el resumen del cliente).
  Future<List<PrestamoModel>> obtenerPorCliente(String clienteId) async {
    final snap = await _col.where('clienteId', isEqualTo: clienteId).get();
    final prestamos = <PrestamoModel>[];
    for (final doc in snap.docs) {
      try {
        final p = PrestamoModel.fromDoc(doc);
        if (!p.eliminado) prestamos.add(p);
      } catch (_) {
        // documento con formato inesperado: se omite.
      }
    }
    return prestamos;
  }

  /// Reasigna el cobrador del prestamo (usado al "Asignar Cobrador" a un
  /// cliente, que cascadea a todos sus prestamos activos).
  Future<void> reasignarCobrador(String id, String cobradorUid) async {
    await _col.doc(id).update({
      'cobradorAsignado': cobradorUid,
      'fechaUltimaActualizacion': FieldValue.serverTimestamp(),
    });
  }

  /// Cantidad de prestamos en mora (para el stat "Pagos Tarde").
  Future<int> contarEnMora({String? cobradorUid}) async {
    Query<Map<String, dynamic>> query = _col.where('estado', isEqualTo: 'mora');
    if (cobradorUid != null) {
      query = query.where('cobradorAsignado', isEqualTo: cobradorUid);
    }
    final agg = await query.count().get();
    return agg.count ?? 0;
  }

  /// Suma del saldo pendiente de todos los prestamos no eliminados (para
  /// el stat "Pendiente"). Se agrega en el servidor, no se descargan
  /// los documentos.
  Future<double> sumarSaldoPendiente({String? cobradorUid}) async {
    Query<Map<String, dynamic>> query = _col.where('eliminado', isEqualTo: false);
    if (cobradorUid != null) {
      query = query.where('cobradorAsignado', isEqualTo: cobradorUid);
    }
    final agg = await query.aggregate(sum('saldo')).get();
    return (agg.getSum('saldo') ?? 0).toDouble();
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

  Future<void> actualizar(String id, Map<String, dynamic> datos) async {
    await _col.doc(id).update({
      ...datos,
      'fechaUltimaActualizacion': FieldValue.serverTimestamp(),
    });
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

  /// Borra el documento de verdad (a diferencia de marcarEliminado, que
  /// es un soft-delete). Se usa desde el modo "Ver eliminados" para
  /// purgar definitivamente.
  Future<void> eliminarPermanente(String id) async {
    await _col.doc(id).delete();
  }

  /// Purga TODOS los prestamos ya marcados como eliminados (soft-delete)
  /// del alcance dado. Usa batches de 400 escrituras (limite de Firestore
  /// es 500 por batch).
  Future<int> eliminarTodosLosEliminados({String? cobradorUid}) async {
    Query<Map<String, dynamic>> query = _col.where('eliminado', isEqualTo: true);
    if (cobradorUid != null) {
      query = query.where('cobradorAsignado', isEqualTo: cobradorUid);
    }
    final snap = await query.get();
    var borrados = 0;
    for (var i = 0; i < snap.docs.length; i += 400) {
      final lote = snap.docs.skip(i).take(400);
      final batch = _db.batch();
      for (final doc in lote) {
        batch.delete(doc.reference);
        borrados++;
      }
      await batch.commit();
    }
    return borrados;
  }
}
