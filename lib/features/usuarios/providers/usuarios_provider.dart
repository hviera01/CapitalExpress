import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/usuario_simple.dart';
import '../data/usuario_repository.dart';

final usuarioRepositoryProvider = Provider<UsuarioRepository>((ref) => UsuarioRepository());

/// Lista de cobradores cacheada por sesion -- es personal interno, casi
/// no cambia, y se pedia de nuevo (viaje redondo a Firestore) cada vez
/// que se abria Ver Clientes, Resumen del Cliente, Reporte de Clientes
/// o Reporte de Cobros. Con `FutureProvider` (sin autoDispose) Riverpod
/// guarda el resultado una sola vez por sesion; `invalidate` despues de
/// crear/editar un usuario fuerza que la proxima lectura traiga la lista
/// al dia.
final cobradoresCacheProvider = FutureProvider<List<UsuarioSimple>>((ref) {
  return ref.watch(usuarioRepositoryProvider).obtenerCobradores();
});
