import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/roles.dart';
import '../../../../core/models/prestamo_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/prestamos_provider.dart';

class PrestamosListScreen extends ConsumerWidget {
  const PrestamosListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authProvider).usuario;
    final esAdmin = usuario?.rol == Roles.admin;
    final cobradorUid = esAdmin ? null : usuario?.uid;

    final verEliminados = ref.watch(verEliminadosProvider);
    final query = PrestamosQuery(cobradorUid: cobradorUid, incluirEliminados: verEliminados);
    final prestamosAsync = ref.watch(prestamosStreamProvider(query));
    final busqueda = ref.watch(busquedaPrestamosProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ver Préstamos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/prestamos/nuevo'),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo préstamo'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar por cliente o número de préstamo',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => ref.read(busquedaPrestamosProvider.notifier).state = v,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('Ver eliminados', style: TextStyle(fontSize: 13)),
                Switch(
                  value: verEliminados,
                  onChanged: (v) => ref.read(verEliminadosProvider.notifier).state = v,
                ),
              ],
            ),
          ),
          Expanded(
            child: prestamosAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error al cargar préstamos: $e')),
              data: (prestamos) {
                final filtrados = filtrarPrestamos(prestamos, busqueda);
                if (filtrados.isEmpty) {
                  return const Center(child: Text('No hay préstamos'));
                }
                return Column(
                  children: [
                    _Resumen(prestamos: filtrados),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: filtrados.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => _PrestamoTile(prestamo: filtrados[i]),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Resumen extends StatelessWidget {
  final List<PrestamoModel> prestamos;

  const _Resumen({required this.prestamos});

  @override
  Widget build(BuildContext context) {
    final activos = prestamos.where((p) => p.estado != 'saldado').length;
    final saldoTotal = prestamos.fold<double>(0, (acc, p) => acc + p.saldo);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Expanded(child: _StatCard(titulo: 'Activos', valor: '$activos')),
          const SizedBox(width: 12),
          Expanded(child: _StatCard(titulo: 'Saldo total', valor: formatearLempiras(saldoTotal))),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String titulo;
  final String valor;

  const _StatCard({required this.titulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontSize: 12, color: CEColors.textSecondary)),
            const SizedBox(height: 4),
            Text(valor, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

class _PrestamoTile extends StatelessWidget {
  final PrestamoModel prestamo;

  const _PrestamoTile({required this.prestamo});

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
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(prestamo.cliente, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('N° ${prestamo.numeroPrestamo} · ${prestamo.plazo}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(formatearLempiras(prestamo.saldo),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _colorEstado().withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                prestamo.estado,
                style: TextStyle(fontSize: 11, color: _colorEstado(), fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        onTap: () => context.push('/prestamos/${prestamo.prestamoId}'),
      ),
    );
  }
}
