import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/roles.dart';
import '../../../../core/models/prestamo_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/widgets/ce_card.dart';
import '../../../../core/widgets/ce_scaffold.dart';
import '../../../../core/widgets/ce_stat_card.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/prestamos_provider.dart';

const _estadosFiltro = ['Todos', 'Activo', 'Mora', 'Saldado'];

class PrestamosListScreen extends ConsumerWidget {
  const PrestamosListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authProvider).usuario;
    final esAdmin = usuario?.rol == Roles.admin;
    final cobradorUid = esAdmin ? null : usuario?.uid;

    final verEliminados = ref.watch(verEliminadosProvider);
    final estadoFiltro = ref.watch(filtroEstadoPrestamosProvider);
    final busqueda = ref.watch(busquedaPrestamosProvider);

    final query = PrestamosQuery(cobradorUid: cobradorUid, incluirEliminados: verEliminados);
    final prestamosAsync = ref.watch(prestamosStreamProvider(query));

    final hayFiltros = busqueda.isNotEmpty || estadoFiltro != 'Todos' || verEliminados;

    return CeScaffold(
      maxWidth: 900,
      appBar: AppBar(
        backgroundColor: verEliminados ? CEColors.danger : null,
        title: Text(verEliminados ? 'Préstamos eliminados' : 'Préstamos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(prestamosStreamProvider(query)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/prestamos/nuevo'),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo préstamo'),
      ),
      body: prestamosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error al cargar préstamos: $e')),
        data: (prestamos) {
          var filtrados = filtrarPrestamos(prestamos, busqueda);
          if (estadoFiltro != 'Todos') {
            final estado = estadoFiltro.toLowerCase();
            filtrados = filtrados.where((p) => p.estado.toLowerCase() == estado).toList();
          }

          final activos = prestamos.where((p) => p.estado != 'saldado').length;
          final saldados = prestamos.where((p) => p.estado == 'saldado').length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              CeCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Buscar cliente o número...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (v) => ref.read(busquedaPrestamosProvider.notifier).state = v,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 18, color: CEColors.danger),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text('Ver eliminados', style: TextStyle(fontSize: 13)),
                        ),
                        Switch(
                          value: verEliminados,
                          activeThumbColor: CEColors.danger,
                          onChanged: (v) => ref.read(verEliminadosProvider.notifier).state = v,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Estado de préstamo',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _estadosFiltro
                          .map((e) => ChoiceChip(
                                label: Text(e),
                                selected: estadoFiltro == e,
                                onSelected: (_) =>
                                    ref.read(filtroEstadoPrestamosProvider.notifier).state = e,
                              ))
                          .toList(),
                    ),
                    if (hayFiltros) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ref.read(busquedaPrestamosProvider.notifier).state = '';
                            ref.read(filtroEstadoPrestamosProvider.notifier).state = 'Todos';
                            ref.read(verEliminadosProvider.notifier).state = false;
                          },
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Limpiar filtros'),
                        ),
                      ),
                    ],
                    if (verEliminados && prestamosAsync.value?.isNotEmpty == true) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: CEColors.danger,
                            side: const BorderSide(color: CEColors.danger),
                          ),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Eliminar todos'),
                                content: const Text(
                                    'Se borrarán definitivamente todos los préstamos eliminados. Esta acción no se puede deshacer.'),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancelar')),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Eliminar todos',
                                        style: TextStyle(color: CEColors.danger)),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) {
                              final borrados = await ref
                                  .read(prestamoRepositoryProvider)
                                  .eliminarTodosLosEliminados(cobradorUid: cobradorUid);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('$borrados préstamo(s) borrados')),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.delete_forever_outlined, size: 16),
                          label: const Text('Eliminar todos permanentemente'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.0,
                children: [
                  CeStatCard(icono: Icons.payments_outlined, valor: '${prestamos.length}', etiqueta: 'TOTAL'),
                  CeStatCard(
                      icono: Icons.check_circle_outline,
                      valor: '$activos',
                      etiqueta: 'ACTIVOS',
                      color: CEColors.success),
                  CeStatCard(
                      icono: Icons.history_toggle_off,
                      valor: '$saldados',
                      etiqueta: 'SALDADOS',
                      color: CEColors.accent),
                ],
              ),
              const SizedBox(height: 16),
              if (filtrados.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: Text('No hay préstamos')),
                )
              else
                ...filtrados.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PrestamoCard(prestamo: p, eliminadoView: verEliminados),
                    )),
            ],
          );
        },
      ),
    );
  }
}

class _PrestamoCard extends ConsumerWidget {
  final PrestamoModel prestamo;
  final bool eliminadoView;

  const _PrestamoCard({required this.prestamo, required this.eliminadoView});

  Color _colorEstado() {
    switch (prestamo.estado) {
      case 'saldado':
        return CEColors.success;
      case 'mora':
        return CEColors.danger;
      default:
        return CEColors.accent;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CeCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push('/prestamos/${prestamo.prestamoId}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (eliminadoView)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: const BoxDecoration(
                color: CEColors.danger,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: const Center(
                child: Text('ELIMINADO',
                    style: TextStyle(
                        color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(prestamo.cliente,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: CEColors.surface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('#${prestamo.numeroPrestamo}',
                          style: const TextStyle(fontSize: 10, color: CEColors.textSecondary)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(formatearLempiras(prestamo.saldo),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 20, color: CEColors.accent)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _colorEstado().withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        prestamo.estado.toUpperCase(),
                        style: TextStyle(
                            fontSize: 11, color: _colorEstado(), fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    _mini(formatearLempiras(prestamo.cuota), 'Cuota'),
                    _mini('${prestamo.cuotas}', 'Cuotas'),
                    _mini(prestamo.plazo, 'Plazo'),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 14, color: CEColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      prestamo.cobrador.isEmpty ? 'Sin asignar' : prestamo.cobrador,
                      style: const TextStyle(fontSize: 12, color: CEColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context.push('/prestamos/${prestamo.prestamoId}'),
                        child: const Text('Ver'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: eliminadoView ? CEColors.success : CEColors.danger,
                          side: BorderSide(
                            color: eliminadoView ? CEColors.success : CEColors.danger,
                          ),
                        ),
                        onPressed: () async {
                          final repo = ref.read(prestamoRepositoryProvider);
                          if (eliminadoView) {
                            await repo.restaurar(prestamo.prestamoId);
                          } else {
                            final usuario = ref.read(authProvider).usuario!;
                            await repo.marcarEliminado(prestamo.prestamoId,
                                eliminadoPor: usuario.nombre);
                          }
                        },
                        child: Text(eliminadoView ? 'Restaurar' : 'Eliminar'),
                      ),
                    ),
                  ],
                ),
                if (eliminadoView) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: CEColors.danger),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Eliminar permanentemente'),
                            content: Text(
                                '¿Borrar definitivamente el préstamo de ${prestamo.cliente}? Esta acción no se puede deshacer.'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancelar')),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Eliminar',
                                    style: TextStyle(color: CEColors.danger)),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await ref
                              .read(prestamoRepositoryProvider)
                              .eliminarPermanente(prestamo.prestamoId);
                        }
                      },
                      icon: const Icon(Icons.delete_forever_outlined, size: 16),
                      label: const Text('Eliminar permanentemente'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mini(String valor, String etiqueta) {
    return Expanded(
      child: Column(
        children: [
          Text(valor, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 2),
          Text(etiqueta, style: const TextStyle(fontSize: 10, color: CEColors.textSecondary)),
        ],
      ),
    );
  }
}
