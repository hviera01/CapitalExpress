import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/storage_service.dart';
import 'ticket_model.dart';

class TicketRepository {
  final _col = FirebaseFirestore.instance.collection('tickets');

  Future<void> crear({
    required String tipo,
    required String titulo,
    required String descripcion,
    required List<Uint8List> fotos,
    required String uid,
    required String nombre,
    required String rol,
  }) async {
    final storage = StorageService();
    final urls = await Future.wait(
      fotos.map((bytes) => storage.subirFoto(bytes: bytes, carpeta: 'tickets')),
    );
    await _col.add({
      'tipo': tipo,
      'titulo': titulo,
      'descripcion': descripcion,
      'fotos': urls,
      'estado': 'enviado',
      'creadoPorUid': uid,
      'creadoPorNombre': nombre,
      'creadoPorRol': rol,
      'fechaCreacion': FieldValue.serverTimestamp(),
      'respuesta': '',
      'precioCotizado': null,
      'fechaRespuesta': null,
      'respondidoPor': '',
    });
  }

  Stream<TicketModel?> streamPorId(String id) {
    return _col.doc(id).snapshots().map((doc) => doc.exists ? TicketModel.fromMap(doc.id, doc.data()!) : null);
  }

  /// Todos los tickets (solo admin) -- unico campo ordenado, no necesita
  /// indice compuesto.
  Stream<List<TicketModel>> streamTodos() {
    return _col.orderBy('fechaCreacion', descending: true).snapshots().map(
        (snap) => snap.docs.map((d) => TicketModel.fromMap(d.id, d.data())).toList());
  }

  /// Tickets creados por este usuario. Ordena en el cliente (no en el
  /// servidor) para no necesitar un indice compuesto por
  /// `creadoPorUid` + `fechaCreacion` -- la cantidad de tickets de una
  /// sola persona es chica, no hace falta paginar/indexar esto.
  Stream<List<TicketModel>> streamPropios(String uid) {
    return _col.where('creadoPorUid', isEqualTo: uid).snapshots().map((snap) {
      final tickets = snap.docs.map((d) => TicketModel.fromMap(d.id, d.data())).toList();
      tickets.sort((a, b) => (b.fechaCreacion ?? DateTime(0)).compareTo(a.fechaCreacion ?? DateTime(0)));
      return tickets;
    });
  }

  /// Cantidad de tickets sin leer (para el badge del menu, solo admin).
  Stream<int> streamNoLeidosCount() {
    return _col.where('estado', isEqualTo: 'enviado').snapshots().map((s) => s.docs.length);
  }

  Future<void> marcarRecibido(String id) async {
    await _col.doc(id).update({'estado': 'recibido'});
  }

  Future<void> responderYCerrar(
    String id, {
    required String respuesta,
    double? precioCotizado,
    required String respondidoPor,
  }) async {
    await _col.doc(id).update({
      'respuesta': respuesta,
      'precioCotizado': precioCotizado,
      'fechaRespuesta': FieldValue.serverTimestamp(),
      'respondidoPor': respondidoPor,
      'estado': 'cerrado',
    });
  }

  Future<void> reabrir(String id) async {
    await _col.doc(id).update({'estado': 'reabierto'});
  }
}
