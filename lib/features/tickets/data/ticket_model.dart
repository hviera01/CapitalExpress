import 'package:cloud_firestore/cloud_firestore.dart';

/// Ticket de soporte: un problema reportado o algo nuevo que un
/// usuario (admin o cobrador) quiere pedir. Ciclo de vida:
/// enviado -> recibido (admin lo leyo) -> cerrado (admin respondio,
/// y si es 'nuevo' incluye el precio cotizado) -> reabierto (quien lo
/// creo, o admin, lo reabre) -> puede volver a cerrarse.
class TicketModel {
  final String id;
  final String tipo; // 'problema' | 'nuevo'
  final String titulo;
  final String descripcion;
  final List<String> fotos; // hasta 3 URLs
  final String estado; // 'enviado' | 'recibido' | 'cerrado' | 'reabierto'
  final String creadoPorUid;
  final String creadoPorNombre;
  final String creadoPorRol;
  final DateTime? fechaCreacion;
  final String respuesta;
  final double? precioCotizado; // solo tiene sentido si tipo == 'nuevo'
  final DateTime? fechaRespuesta;
  final String respondidoPor;

  const TicketModel({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.descripcion,
    required this.fotos,
    required this.estado,
    required this.creadoPorUid,
    required this.creadoPorNombre,
    required this.creadoPorRol,
    required this.fechaCreacion,
    required this.respuesta,
    required this.precioCotizado,
    required this.fechaRespuesta,
    required this.respondidoPor,
  });

  bool get esProblema => tipo == 'problema';
  bool get tieneRespuesta => respuesta.isNotEmpty;

  factory TicketModel.fromMap(String id, Map<String, dynamic> data) {
    return TicketModel(
      id: id,
      tipo: (data['tipo'] as String?) ?? 'problema',
      titulo: (data['titulo'] as String?) ?? '',
      descripcion: (data['descripcion'] as String?) ?? '',
      fotos: (data['fotos'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      estado: (data['estado'] as String?) ?? 'enviado',
      creadoPorUid: (data['creadoPorUid'] as String?) ?? '',
      creadoPorNombre: (data['creadoPorNombre'] as String?) ?? '',
      creadoPorRol: (data['creadoPorRol'] as String?) ?? '',
      fechaCreacion: (data['fechaCreacion'] as Timestamp?)?.toDate(),
      respuesta: (data['respuesta'] as String?) ?? '',
      precioCotizado: (data['precioCotizado'] as num?)?.toDouble(),
      fechaRespuesta: (data['fechaRespuesta'] as Timestamp?)?.toDate(),
      respondidoPor: (data['respondidoPor'] as String?) ?? '',
    );
  }
}
