import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/models/cliente_model.dart';
import '../../../core/utils/normalizar_texto.dart';
import '../data/cliente_repository.dart';

final clienteRepositoryProvider = Provider<ClienteRepository>((ref) => ClienteRepository());

/// null = admin (ve todos); un uid = cobrador (ve solo los suyos).
final clientesStreamProvider =
    StreamProvider.family<List<ClienteModel>, String?>((ref, cobradorUid) {
  return ref.watch(clienteRepositoryProvider).streamClientes(cobradorUid: cobradorUid);
});

final busquedaClientesProvider = StateProvider.autoDispose<String>((ref) => '');
final filtroEstadoClientesProvider = StateProvider.autoDispose<String>((ref) => 'Todos');

List<ClienteModel> filtrarClientes(List<ClienteModel> clientes, String busqueda) {
  if (busqueda.trim().isEmpty) return clientes;
  return clientes
      .where((c) =>
          coincideBusqueda(c.nombre, busqueda) ||
          coincideBusqueda(c.identidad, busqueda) ||
          coincideBusqueda(c.telefono, busqueda))
      .toList();
}
