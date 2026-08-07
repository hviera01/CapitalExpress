import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/models/prestamo_model.dart';
import '../../../core/utils/normalizar_texto.dart';
import '../data/prestamo_repository.dart';

final prestamoRepositoryProvider = Provider<PrestamoRepository>((ref) => PrestamoRepository());

class PrestamosQuery {
  final String? cobradorUid;
  final bool incluirEliminados;

  const PrestamosQuery({this.cobradorUid, this.incluirEliminados = false});

  @override
  bool operator ==(Object other) =>
      other is PrestamosQuery &&
      other.cobradorUid == cobradorUid &&
      other.incluirEliminados == incluirEliminados;

  @override
  int get hashCode => Object.hash(cobradorUid, incluirEliminados);
}

final prestamosStreamProvider =
    StreamProvider.family<List<PrestamoModel>, PrestamosQuery>((ref, query) {
  return ref.read(prestamoRepositoryProvider).streamPrestamos(
        cobradorUid: query.cobradorUid,
        incluirEliminados: query.incluirEliminados,
      );
});

final busquedaPrestamosProvider = StateProvider.autoDispose<String>((ref) => '');
final verEliminadosProvider = StateProvider.autoDispose<bool>((ref) => false);

List<PrestamoModel> filtrarPrestamos(List<PrestamoModel> prestamos, String busqueda) {
  if (busqueda.trim().isEmpty) return prestamos;
  final q = normalizarTexto(busqueda);
  return prestamos
      .where((p) =>
          normalizarTexto(p.cliente).contains(q) || normalizarTexto(p.numeroPrestamo).contains(q))
      .toList();
}
