import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/usuario_model.dart';

/// Guarda la ultima lista de Ver Usuarios (y los prestamos asignados
/// por cobrador) para que al salir de la pantalla y volver a entrar
/// se vea de una -- mismo patron que ClientesBusquedaCache.
class UsuariosCache {
  bool tieneDatos = false;
  List<UsuarioModel> usuarios = [];
  Map<String, int> prestamosAsignados = {};
}

final usuariosCacheProvider = Provider<UsuariosCache>((ref) => UsuariosCache());
