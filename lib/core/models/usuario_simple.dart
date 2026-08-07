import 'package:cloud_firestore/cloud_firestore.dart';

/// Version liviana de un usuario (para listas de seleccion, ej. cobradores).
class UsuarioSimple {
  final String uid;
  final String nombre;
  final String rol;
  final String estado;

  const UsuarioSimple({
    required this.uid,
    required this.nombre,
    required this.rol,
    required this.estado,
  });

  factory UsuarioSimple.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return UsuarioSimple(
      uid: doc.id,
      nombre: (d['nombre'] ?? '') as String,
      rol: (d['rol'] ?? '') as String,
      estado: (d['estado'] ?? 'activo') as String,
    );
  }
}
