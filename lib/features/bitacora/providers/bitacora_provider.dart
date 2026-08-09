import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bitacora_model.dart';
import '../data/bitacora_repository.dart';

final bitacoraRepositoryProvider = Provider((ref) => BitacoraRepository());

final bitacoraStreamProvider = StreamProvider<List<BitacoraModel>>((ref) {
  return ref.watch(bitacoraRepositoryProvider).streamRecientes();
});
