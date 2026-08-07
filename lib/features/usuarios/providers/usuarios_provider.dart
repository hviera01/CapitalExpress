import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/usuario_repository.dart';

final usuarioRepositoryProvider = Provider<UsuarioRepository>((ref) => UsuarioRepository());
