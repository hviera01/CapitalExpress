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

List<ClienteModel> filtrarClientes(List<ClienteModel> clientes, String busqueda) {
  if (busqueda.trim().isEmpty) return clientes;
  final q = normalizarTexto(busqueda);
  return clientes
      .where((c) =>
          normalizarTexto(c.nombre).contains(q) ||
          normalizarTexto(c.identidad).contains(q) ||
          normalizarTexto(c.telefono).contains(q))
      .toList();
}
