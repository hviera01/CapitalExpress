import 'package:cloud_firestore/cloud_firestore.dart';

/// Espejo del doc `solicitudes_edicion` en Firestore: un cobrador pide
/// editar un cliente/prestamo fuera de la hora libre desde su creacion
/// (ver puedeEditarLibre en core/utils/permisos_edicion.dart),
/// mencionando los campos exactos que quiere cambiar y su valor nuevo.
/// Si el admin aprueba, se le otorga acceso de edicion por 1 hora (un
/// solo uso) sobre esa entidad -- ver SolicitudEdicionRepository.
///
/// A diferencia de `solicitudes_prestamo` (SolicitudModel, que se borra
/// al decidir), estos documentos se CONSERVAN en todos sus estados
/// terminales: sirven de historial de auditoria de quien pidio editar
/// que y cuando, complementario a la bitacora.
class SolicitudEdicionModel {
  final String id;
  final String entidadTipo; // 'cliente' | 'prestamo'
  final String entidadId;
  final String entidadNombre;
  final Map<String, dynamic> valoresNuevos;
  final Map<String, dynamic> valoresAnteriores;
  final String estado; // 'pendiente' | 'aprobada' | 'rechazada' | 'aplicada' | 'vencida'
  final String solicitanteUid;
  final String solicitanteNombre;
  final Timestamp? fechaCreacion;
  final String? aprobadaPorUid;
  final String? aprobadaPorNombre;
  final Timestamp? fechaAprobacion;
  final Timestamp? fechaExpiraPermiso;
  final Timestamp? fechaUso;
  final String? motivoRechazo;

  const SolicitudEdicionModel({
    required this.id,
    this.entidadTipo = '',
    this.entidadId = '',
    this.entidadNombre = '',
    this.valoresNuevos = const {},
    this.valoresAnteriores = const {},
    this.estado = 'pendiente',
    this.solicitanteUid = '',
    this.solicitanteNombre = '',
    this.fechaCreacion,
    this.aprobadaPorUid,
    this.aprobadaPorNombre,
    this.fechaAprobacion,
    this.fechaExpiraPermiso,
    this.fechaUso,
    this.motivoRechazo,
  });

  /// true si esta aprobada, todavia no se uso, y la hora otorgada no
  /// paso -- es lo que habilita abrir el formulario de edicion normal.
  bool get permisoVigente {
    if (estado != 'aprobada') return false;
    final expira = fechaExpiraPermiso?.toDate();
    if (expira == null) return false;
    return DateTime.now().isBefore(expira);
  }

  factory SolicitudEdicionModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return SolicitudEdicionModel(
      id: doc.id,
      entidadTipo: (d['entidadTipo'] ?? '') as String,
      entidadId: (d['entidadId'] ?? '') as String,
      entidadNombre: (d['entidadNombre'] ?? '') as String,
      valoresNuevos: Map<String, dynamic>.from((d['valoresNuevos'] as Map?) ?? const {}),
      valoresAnteriores: Map<String, dynamic>.from((d['valoresAnteriores'] as Map?) ?? const {}),
      estado: (d['estado'] ?? 'pendiente') as String,
      solicitanteUid: (d['solicitanteUid'] ?? '') as String,
      solicitanteNombre: (d['solicitanteNombre'] ?? '') as String,
      fechaCreacion: d['fechaCreacion'] as Timestamp?,
      aprobadaPorUid: d['aprobadaPorUid'] as String?,
      aprobadaPorNombre: d['aprobadaPorNombre'] as String?,
      fechaAprobacion: d['fechaAprobacion'] as Timestamp?,
      fechaExpiraPermiso: d['fechaExpiraPermiso'] as Timestamp?,
      fechaUso: d['fechaUso'] as Timestamp?,
      motivoRechazo: d['motivoRechazo'] as String?,
    );
  }
}
