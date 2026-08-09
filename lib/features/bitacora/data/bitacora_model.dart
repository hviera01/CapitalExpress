import 'package:cloud_firestore/cloud_firestore.dart';

/// Una entrada de la Bitacora de Seguridad: quien hizo que, cuando.
/// Por ahora solo se registran eliminaciones (cliente/prestamo/pago),
/// ver BitacoraRepository.registrar.
class BitacoraModel {
  final String id;
  final String accion; // ej. 'eliminar_cliente'
  final String entidadTipo; // 'cliente' | 'prestamo' | 'pago'
  final String descripcion; // texto ya armado, listo para mostrar
  final String usuarioUid;
  final String usuarioNombre;
  final DateTime? fecha;

  const BitacoraModel({
    required this.id,
    required this.accion,
    required this.entidadTipo,
    required this.descripcion,
    required this.usuarioUid,
    required this.usuarioNombre,
    required this.fecha,
  });

  factory BitacoraModel.fromMap(String id, Map<String, dynamic> data) {
    return BitacoraModel(
      id: id,
      accion: (data['accion'] as String?) ?? '',
      entidadTipo: (data['entidadTipo'] as String?) ?? '',
      descripcion: (data['descripcion'] as String?) ?? '',
      usuarioUid: (data['usuarioUid'] as String?) ?? '',
      usuarioNombre: (data['usuarioNombre'] as String?) ?? '',
      fecha: (data['fecha'] as Timestamp?)?.toDate(),
    );
  }
}
