import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/usuario_model.dart';
import '../../../core/models/usuario_simple.dart';
import '../../bitacora/data/bitacora_repository.dart';

class UsuarioRepository {
  final _col = FirebaseFirestore.instance.collection('usuarios');
  static const _uuid = Uuid();

  Future<List<UsuarioSimple>> obtenerCobradores() async {
    final snap = await _col.where('rol', isEqualTo: 'cobrador').get();
    return snap.docs.map(UsuarioSimple.fromDoc).toList()
      ..sort((a, b) => a.nombre.compareTo(b.nombre));
  }

  /// Todos los usuarios (staff), para Ver Usuarios -- es una coleccion
  /// chica (personal interno), no hace falta paginar ni filtrar en el
  /// servidor como en clientes/prestamos.
  Future<List<UsuarioModel>> obtenerTodos() async {
    final snap = await _col.get();
    final usuarios = snap.docs.map(UsuarioModel.fromDoc).toList();
    usuarios.sort((a, b) => a.nombre.compareTo(b.nombre));
    return usuarios;
  }

  Future<UsuarioModel?> obtenerPorId(String uid) async {
    final doc = await _col.doc(uid).get();
    return doc.exists ? UsuarioModel.fromDoc(doc) : null;
  }

  /// Igual que CrearUsuarioScreen.kt / EditarUsuarioScreen.kt: el
  /// codigo debe ser unico en toda la coleccion.
  Future<bool> existeCodigo(String codigo, {String? excluirUid}) async {
    final snap = await _col.where('codigo', isEqualTo: codigo).get();
    return snap.docs.any((d) => d.id != excluirUid);
  }

  Future<String> crear(UsuarioModel usuario) async {
    final uid = _uuid.v4();
    await _col.doc(uid).set(usuario.toMap());
    return uid;
  }

  Future<void> actualizar(
    UsuarioModel usuario, {
    required String usuarioUid,
    required String usuarioNombre,
  }) async {
    await _col.doc(usuario.uid).update(usuario.toMap());
    BitacoraRepository().registrar(
      accion: 'editar_usuario',
      entidadTipo: 'usuario',
      descripcion: usuario.nombre.isNotEmpty ? usuario.nombre : 'Usuario (UID: ${usuario.uid})',
      usuarioUid: usuarioUid,
      usuarioNombre: usuarioNombre,
    );
  }

  Future<void> actualizarEstado(String uid, String estado) async {
    await _col.doc(uid).update({'estado': estado});
  }
}
