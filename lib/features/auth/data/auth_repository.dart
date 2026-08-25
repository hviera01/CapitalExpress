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
  static const _kBloqueado = 'sesionBloqueada';
  static const _kBiometricoActivo = 'biometricoActivo';
  static const _kFechaBackground = 'fechaBackground';

  /// Tiempo maximo con la app en segundo plano (sin quitarla de la
  /// multitarea) antes de pedir que se desbloquee de nuevo -- si la
  /// quita de la multitarea, el cierre es inmediato (ver
  /// SesionNativaService/MainActivity.onTaskRemoved), esto es aparte
  /// para cuando solo la deja "abierta" en segundo plano.
  static const limiteBackground = Duration(hours: 1);

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
    await prefs.remove(_kBloqueado);
    await prefs.remove(_kFechaBackground);
    // _kBiometricoActivo NO se borra: es una preferencia del
    // dispositivo/usuario, no de la sesion -- que siga activada para
    // la proxima vez que inicie sesion en este telefono.
  }

  /// Compara la contrasena SIN pedir de nuevo el codigo (ya se conoce
  /// el uid de la sesion guardada) -- usado para desbloquear cuando no
  /// hay huella/Face ID configurado.
  Future<bool> verificarPassword(String uid, String password) async {
    final doc = await _col.doc(uid).get();
    if (!doc.exists) return false;
    return (doc.data()?['password'] as String?) == password;
  }

  Future<bool> estaBloqueado() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kBloqueado) ?? false;
  }

  Future<void> bloquear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBloqueado, true);
  }

  Future<void> desbloquear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBloqueado, false);
    await prefs.remove(_kFechaBackground);
  }

  Future<void> marcarBackground() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFechaBackground, DateTime.now().toIso8601String());
  }

  Future<bool> backgroundExcedioLimite() async {
    final prefs = await SharedPreferences.getInstance();
    final guardada = prefs.getString(_kFechaBackground);
    if (guardada == null) return false;
    final desde = DateTime.tryParse(guardada);
    if (desde == null) return false;
    return DateTime.now().difference(desde) > limiteBackground;
  }

  Future<bool> biometricoActivo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kBiometricoActivo) ?? false;
  }

  Future<void> setBiometricoActivo(bool activo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBiometricoActivo, activo);
  }
}
