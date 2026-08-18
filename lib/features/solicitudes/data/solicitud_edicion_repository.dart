import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/solicitud_edicion_model.dart';
import '../../bitacora/data/bitacora_repository.dart';

class SolicitudEdicionRepository {
  final _col = FirebaseFirestore.instance.collection('solicitudes_edicion');

  Stream<List<SolicitudEdicionModel>> streamPendientes() {
    return _col.where('estado', isEqualTo: 'pendiente').snapshots().map((snap) {
      final solicitudes = <SolicitudEdicionModel>[];
      for (final doc in snap.docs) {
        try {
          solicitudes.add(SolicitudEdicionModel.fromDoc(doc));
        } catch (_) {
          // documento con formato inesperado: se omite.
        }
      }
      solicitudes.sort((a, b) =>
          (b.fechaCreacion?.compareTo(a.fechaCreacion ?? b.fechaCreacion!) ?? 0));
      return solicitudes;
    });
  }

  /// TODAS las solicitudes (cualquier estado) que mando este usuario --
  /// para "Mis Solicitudes" del cobrador, que necesita ver el historial
  /// completo (pendiente/aprobada/rechazada/aplicada/vencida), no solo
  /// las pendientes como la pantalla del admin.
  Stream<List<SolicitudEdicionModel>> streamPorSolicitante(String solicitanteUid) {
    return _col.where('solicitanteUid', isEqualTo: solicitanteUid).snapshots().map((snap) {
      final solicitudes = <SolicitudEdicionModel>[];
      for (final doc in snap.docs) {
        try {
          solicitudes.add(SolicitudEdicionModel.fromDoc(doc));
        } catch (_) {
          // documento con formato inesperado: se omite.
        }
      }
      solicitudes.sort((a, b) =>
          (b.fechaCreacion?.compareTo(a.fechaCreacion ?? b.fechaCreacion!) ?? 0));
      return solicitudes;
    });
  }

  Stream<SolicitudEdicionModel?> streamPorId(String id) {
    return _col.doc(id).snapshots().map((doc) => doc.exists ? SolicitudEdicionModel.fromDoc(doc) : null);
  }

  Future<void> crear({
    required String entidadTipo,
    required String entidadId,
    required String entidadNombre,
    required Map<String, dynamic> valoresNuevos,
    required Map<String, dynamic> valoresAnteriores,
    required String solicitanteUid,
    required String solicitanteNombre,
  }) async {
    final docRef = _col.doc();
    await docRef.set({
      'entidadTipo': entidadTipo,
      'entidadId': entidadId,
      'entidadNombre': entidadNombre,
      'valoresNuevos': valoresNuevos,
      'valoresAnteriores': valoresAnteriores,
      'estado': 'pendiente',
      'solicitanteUid': solicitanteUid,
      'solicitanteNombre': solicitanteNombre,
      'fechaCreacion': FieldValue.serverTimestamp(),
    });
    BitacoraRepository().registrar(
      accion: 'crear_solicitud_edicion',
      entidadTipo: 'solicitud',
      descripcion: 'Solicitud de edición de $entidadTipo: $entidadNombre',
      usuarioUid: solicitanteUid,
      usuarioNombre: solicitanteNombre,
    );
  }

  /// Otorga acceso de edicion por 1 hora, de un solo uso -- ver
  /// SolicitudEdicionModel.permisoVigente y
  /// core/utils/permisos_edicion.dart, que es quien lo consulta antes
  /// de dejar entrar al formulario de edicion normal.
  Future<void> aprobar(
    String id, {
    required String usuarioUid,
    required String usuarioNombre,
    String descripcion = '',
  }) async {
    final ahora = Timestamp.now();
    final expira = Timestamp.fromDate(ahora.toDate().add(const Duration(hours: 1)));
    await _col.doc(id).update({
      'estado': 'aprobada',
      'aprobadaPorUid': usuarioUid,
      'aprobadaPorNombre': usuarioNombre,
      'fechaAprobacion': ahora,
      'fechaExpiraPermiso': expira,
    });
    BitacoraRepository().registrar(
      accion: 'aprobar_solicitud_edicion',
      entidadTipo: 'solicitud',
      descripcion: descripcion.isNotEmpty ? descripcion : 'Solicitud de edición (ID: $id)',
      usuarioUid: usuarioUid,
      usuarioNombre: usuarioNombre,
    );
  }

  Future<void> rechazar(
    String id, {
    required String usuarioUid,
    required String usuarioNombre,
    String motivo = '',
    String descripcion = '',
  }) async {
    await _col.doc(id).update({
      'estado': 'rechazada',
      if (motivo.isNotEmpty) 'motivoRechazo': motivo,
    });
    BitacoraRepository().registrar(
      accion: 'rechazar_solicitud_edicion',
      entidadTipo: 'solicitud',
      descripcion: descripcion.isNotEmpty ? descripcion : 'Solicitud de edición (ID: $id)',
      usuarioUid: usuarioUid,
      usuarioNombre: usuarioNombre,
    );
  }

  /// Marca el permiso otorgado como consumido -- se llama desde
  /// ClienteFormScreen/EditarPrestamoScreen justo despues de guardar
  /// exitosamente bajo un `solicitudEdicionId`.
  Future<void> marcarAplicada(
    String id, {
    required String usuarioUid,
    required String usuarioNombre,
    String descripcion = '',
  }) async {
    await _col.doc(id).update({
      'estado': 'aplicada',
      'fechaUso': FieldValue.serverTimestamp(),
    });
    BitacoraRepository().registrar(
      accion: 'aplicar_solicitud_edicion',
      entidadTipo: 'solicitud',
      descripcion: descripcion.isNotEmpty ? descripcion : 'Solicitud de edición (ID: $id)',
      usuarioUid: usuarioUid,
      usuarioNombre: usuarioNombre,
    );
  }

  /// Consulta puntual (no stream): hay un permiso otorgado y vigente
  /// para esta entidad -- se usa al abrir la pantalla de edicion, para
  /// decidir si dejar editar directo o mandar a "Solicitar edición".
  Future<SolicitudEdicionModel?> permisoActivoPara(String entidadId) async {
    final snap = await _col
        .where('entidadId', isEqualTo: entidadId)
        .where('estado', isEqualTo: 'aprobada')
        .get();
    for (final doc in snap.docs) {
      final s = SolicitudEdicionModel.fromDoc(doc);
      if (s.permisoVigente) return s;
    }
    return null;
  }
}
