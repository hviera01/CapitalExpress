import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/usuario_simple.dart';

class UsuarioRepository {
  final _col = FirebaseFirestore.instance.collection('usuarios');

  Future<List<UsuarioSimple>> obtenerCobradores() async {
    final snap = await _col.where('rol', isEqualTo: 'cobrador').get();
    return snap.docs.map(UsuarioSimple.fromDoc).toList()
      ..sort((a, b) => a.nombre.compareTo(b.nombre));
  }
}
