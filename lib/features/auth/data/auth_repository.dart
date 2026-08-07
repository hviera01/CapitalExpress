import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/usuario_model.dart';

class AuthException implements Exception {
  final String mensaje;
  AuthException(this.mensaje);
}

/// Login por codigo+password contra la coleccion `usuarios`, identico al
/// flujo de LoginScreen.kt (sin Firebase Auth): se comparan los campos
/// planos `codigo`/`password` del documento. Se mantiene la misma
/// coleccion/esquema para que ambas apps (Kotlin y Flutter) autentiquen
/// contra los mismos usuarios sin migracion de datos.
class AuthRepository {
  final _col = FirebaseFirestore.instance.collection('usuarios');

  static const _kUid = 'uid';
  static const _kNombre = 'nombre';
  static const _kRol = 'rol';

  Future<UsuarioModel> login(String codigo, String password) async {
    final query = await _col
        .where('codigo', isEqualTo: codigo)
        .where('password', isEqualTo: password)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw AuthException('Codigo o contrasena incorrectos');
    }

    final usuario = UsuarioModel.fromDoc(query.docs.first);
    if (usuario.estado != 'activo') {
      throw AuthException('Este usuario esta inactivo');
    }

    await _guardarSesion(usuario);
    return usuario;
  }

  Future<void> _guardarSesion(UsuarioModel u) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUid, u.uid);
    await prefs.setString(_kNombre, u.nombre);
    await prefs.setString(_kRol, u.rol);
  }

  Future<UsuarioModel?> sesionGuardada() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString(_kUid);
    if (uid == null) return null;

    final doc = await _col.doc(uid).get();
    if (!doc.exists) return null;

    final usuario = UsuarioModel.fromDoc(doc);
    if (usuario.estado != 'activo') {
      await cerrarSesion();
      return null;
    }
    return usuario;
  }

  Future<void> cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUid);
    await prefs.remove(_kNombre);
    await prefs.remove(_kRol);
  }
}
