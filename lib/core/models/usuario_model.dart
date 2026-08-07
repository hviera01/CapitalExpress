import 'package:cloud_firestore/cloud_firestore.dart';

/// Espejo del doc `usuarios` en Firestore, mismo esquema que la app Kotlin
/// original (LoginScreen.kt / CrearUsuarioScreen.kt): sin Firebase Auth,
/// login por codigo+password contra esta coleccion.
class UsuarioModel {
  final String uid;
  final String codigo;
  final String password;
  final String nombre;
  final String rol; // "admin" | "cobrador"
  final String estado; // "activo" | "inactivo"
  final String direccion;
  final String identidad;
  final String telefono;
  final String fotoUrl;

  const UsuarioModel({
    required this.uid,
    required this.codigo,
    required this.password,
    required this.nombre,
    required this.rol,
    required this.estado,
    this.direccion = '',
    this.identidad = '',
    this.telefono = '',
    this.fotoUrl = '',
  });

  factory UsuarioModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return UsuarioModel(
      uid: doc.id,
      codigo: (data['codigo'] ?? '') as String,
      password: (data['password'] ?? '') as String,
      nombre: (data['nombre'] ?? '') as String,
      rol: (data['rol'] ?? '') as String,
      estado: (data['estado'] ?? 'activo') as String,
      direccion: (data['direccion'] ?? '') as String,
      identidad: (data['identidad'] ?? '') as String,
      telefono: (data['telefono'] ?? '') as String,
      fotoUrl: (data['fotoUrl'] ?? '') as String,
    );
  }

  Map<String, dynamic> toMap() => {
        'codigo': codigo,
        'password': password,
        'nombre': nombre,
        'rol': rol,
        'estado': estado,
        'direccion': direccion,
        'identidad': identidad,
        'telefono': telefono,
        'fotoUrl': fotoUrl,
      };
}
