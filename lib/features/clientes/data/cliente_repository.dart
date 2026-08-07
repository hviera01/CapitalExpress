import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/cliente_model.dart';
import '../../../core/utils/normalizar_texto.dart';

class ClienteRepository {
  final _col = FirebaseFirestore.instance.collection('clientes');

  /// Admin ve todos los clientes; cobrador solo los suyos
  /// (`cobradorAsignado == uid`), igual que ClientesVista.kt.
  Stream<List<ClienteModel>> streamClientes({String? cobradorUid}) {
    Query<Map<String, dynamic>> query = _col;
    if (cobradorUid != null) {
      query = query.where('cobradorAsignado', isEqualTo: cobradorUid);
    }
    return query.snapshots().map((snap) {
      final clientes = <ClienteModel>[];
      for (final doc in snap.docs) {
        try {
          clientes.add(ClienteModel.fromDoc(doc));
        } catch (_) {
          // Un documento con un campo en formato inesperado no debe tumbar
          // toda la lista de clientes; se omite y siguen los demas.
        }
      }
      clientes.sort((a, b) => a.nombre.compareTo(b.nombre));
      return clientes;
    });
  }

  /// Busqueda puntual (no streaming): solo trae lo que hace falta, no
  /// toda la coleccion de una. El filtro por cobrador/estado va al
  /// servidor (Firestore); el texto libre se aplica en memoria sobre
  /// ese subconjunto ya acotado.
  Future<List<ClienteModel>> buscar({
    String? cobradorUid,
    String? estado,
    String texto = '',
  }) async {
    Query<Map<String, dynamic>> query = _col;
    if (cobradorUid != null) {
      query = query.where('cobradorAsignado', isEqualTo: cobradorUid);
    }
    if (estado != null) {
      query = query.where('estado', isEqualTo: estado);
    }

    final snap = await query.limit(100).get();
    final clientes = <ClienteModel>[];
    for (final doc in snap.docs) {
      try {
        clientes.add(ClienteModel.fromDoc(doc));
      } catch (_) {
        // documento con formato inesperado: se omite.
      }
    }
    clientes.sort((a, b) => a.nombre.compareTo(b.nombre));

    if (texto.trim().isEmpty) return clientes;
    final q = normalizarTexto(texto);
    return clientes
        .where((c) =>
            normalizarTexto(c.nombre).contains(q) ||
            normalizarTexto(c.identidad).contains(q) ||
            normalizarTexto(c.telefono).contains(q))
        .toList();
  }

  /// Trae TODOS los clientes del alcance (sin limit). A diferencia de
  /// `buscar`, esto es a proposito para el Reporte de Clientes, que
  /// necesita el universo completo para calcular sumas reales -- no es
  /// para pantallas de navegacion cotidiana.
  Future<List<ClienteModel>> obtenerTodos({String? cobradorUid}) async {
    Query<Map<String, dynamic>> query = _col;
    if (cobradorUid != null) {
      query = query.where('cobradorAsignado', isEqualTo: cobradorUid);
    }
    final snap = await query.get();
    final clientes = <ClienteModel>[];
    for (final doc in snap.docs) {
      try {
        clientes.add(ClienteModel.fromDoc(doc));
      } catch (_) {
        // documento con formato inesperado: se omite.
      }
    }
    clientes.sort((a, b) => a.nombre.compareTo(b.nombre));
    return clientes;
  }

  Future<int> contar({String? cobradorUid, String? estado}) async {
    Query<Map<String, dynamic>> query = _col;
    if (cobradorUid != null) {
      query = query.where('cobradorAsignado', isEqualTo: cobradorUid);
    }
    if (estado != null) {
      query = query.where('estado', isEqualTo: estado);
    }
    final agg = await query.count().get();
    return agg.count ?? 0;
  }

  Future<ClienteModel?> obtenerPorId(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return ClienteModel.fromDoc(doc);
  }

  /// Igual que [obtenerPorId] pero en vivo (Resumen del Cliente), para
  /// que un cambio (ej. reasignar cobrador) se refleje sin recargar.
  Stream<ClienteModel?> streamPorId(String id) {
    return _col.doc(id).snapshots().map((doc) => doc.exists ? ClienteModel.fromDoc(doc) : null);
  }

  Future<String> crear(ClienteModel cliente) async {
    final doc = await _col.add({
      ...cliente.toMap(),
      'fechaCreacion': FieldValue.serverTimestamp(),
      'ultimaActividad': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> actualizar(ClienteModel cliente) async {
    await _col.doc(cliente.id).update({
      ...cliente.toMap(),
      'ultimaActividad': FieldValue.serverTimestamp(),
    });
  }

  Future<void> eliminar(String id) async {
    await _col.doc(id).delete();
  }

  /// Reasigna el cobrador de un cliente puntual (usado por "Asignar
  /// Cobrador" en el Resumen del Cliente).
  Future<void> actualizarCobrador(String id, String cobradorUid) async {
    await _col.doc(id).update({
      'cobradorAsignado': cobradorUid,
      'ultimaActividad': FieldValue.serverTimestamp(),
    });
  }
}
