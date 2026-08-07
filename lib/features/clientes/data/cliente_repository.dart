import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/cliente_model.dart';

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

  Future<ClienteModel?> obtenerPorId(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return ClienteModel.fromDoc(doc);
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
}
