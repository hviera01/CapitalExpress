import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/roles.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/ticket_model.dart';
import '../data/ticket_repository.dart';

final ticketRepositoryProvider = Provider((ref) => TicketRepository());

/// Admin ve todos los tickets; cobrador solo los que el creo.
final ticketsStreamProvider = StreamProvider<List<TicketModel>>((ref) {
  final usuario = ref.watch(authProvider).usuario;
  final repo = ref.watch(ticketRepositoryProvider);
  if (usuario == null) return const Stream.empty();
  if (usuario.rol == Roles.admin) return repo.streamTodos();
  return repo.streamPropios(usuario.uid);
});

/// Contador de tickets sin leer (badge de menu) -- solo tiene sentido
/// para admin, que es quien los recibe.
final ticketsNoLeidosProvider = StreamProvider<int>((ref) {
  final usuario = ref.watch(authProvider).usuario;
  if (usuario == null || usuario.rol != Roles.admin) return Stream.value(0);
  return ref.watch(ticketRepositoryProvider).streamNoLeidosCount();
});
