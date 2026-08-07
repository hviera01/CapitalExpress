import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/roles.dart';
import '../../../../core/models/cliente_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/ce_scaffold.dart';
import '../../../../core/widgets/ce_stat_card.dart';
import '../../../../core/widgets/imagen_red_network.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/clientes_provider.dart';

const _estados = ['Todos', 'Activo', 'Inactivo'];

class ClientesListScreen extends ConsumerWidget {
  const ClientesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authProvider).usuario;
    final esAdmin = usuario?.rol == Roles.admin;
    final cobradorUid = esAdmin ? null : usuario?.uid;

    final clientesAsync = ref.watch(clientesStreamProvider(cobradorUid));
    final busqueda = ref.watch(busquedaClientesProvider);
    final filtroEstado = ref.watch(filtroEstadoClientesProvider);

    return CeScaffold(
      maxWidth: 900,
      appBar: AppBar(title: Text(esAdmin ? 'Ver Clientes' : 'Mis Clientes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/clientes/nuevo'),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Nuevo cliente'),
      ),
      body: clientesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error al cargar clientes: $e')),
        data: (clientes) {
          var filtrados = filtrarClientes(clientes, busqueda);
          if (filtroEstado != 'Todos') {
            final estado = filtroEstado == 'Activo' ? 'activo' : 'inactivo';
            filtrados = filtrados.where((c) => c.estado == estado).toList();
          }

          final activos = clientes.where((c) => c.estado == 'activo').length;
          final conPrestamo = clientes.where((c) => c.tienePrestamo).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              GridView.count(
                crossAxisCount: esEscritorio(context) ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.3,
                children: [
                  CeStatCard(
                    icono: Icons.people_outline,
                    valor: '${clientes.length}',
                    etiqueta: 'Total',
                  ),
                  CeStatCard(
                    icono: Icons.trending_up,
                    valor: '$activos',
                    etiqueta: 'Activos',
                    color: CEColors.success,
                  ),
                  CeStatCard(
                    icono: Icons.account_balance_outlined,
                    valor: '$conPrestamo',
                    etiqueta: 'Con préstamo',
                    color: CEColors.accent,
                  ),
                  CeStatCard(
                    icono: Icons.person_off_outlined,
                    valor: '${clientes.length - conPrestamo}',
                    etiqueta: 'Sin préstamo',
                    color: CEColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Buscar por nombre, identidad o teléfono',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => ref.read(busquedaClientesProvider.notifier).state = v,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: filtroEstado,
                decoration: const InputDecoration(labelText: 'Estado'),
                items:
                    _estados.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) =>
                    ref.read(filtroEstadoClientesProvider.notifier).state = v ?? 'Todos',
              ),
              const SizedBox(height: 12),
              Text(
                'Mostrando ${filtrados.length} de ${clientes.length} clientes',
                style: const TextStyle(fontSize: 12, color: CEColors.textSecondary),
              ),
              const SizedBox(height: 8),
              if (filtrados.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: Text('No hay clientes')),
                )
              else
                ...filtrados.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ClienteTile(cliente: c),
                    )),
            ],
          );
        },
      ),
    );
  }
}

class _ClienteTile extends StatelessWidget {
  final ClienteModel cliente;

  const _ClienteTile({required this.cliente});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/clientes/${cliente.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: cliente.fotoClienteUrl.isNotEmpty
                      ? ImagenRedNetwork(url: cliente.fotoClienteUrl)
                      : const ColoredBox(
                          color: CEColors.surface,
                          child: Icon(Icons.person_outline, color: CEColors.textSecondary),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cliente.nombre,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 4),
                    if (cliente.telefono.isNotEmpty)
                      _filaIcono(Icons.call_outlined, cliente.telefono),
                    if (cliente.identidad.isNotEmpty)
                      _filaIcono(Icons.badge_outlined, cliente.identidad),
                    if (cliente.tienePrestamo) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: CEColors.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Con préstamo',
                          style: TextStyle(
                              fontSize: 10, color: CEColors.accent, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: CEColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filaIcono(IconData icono, String texto) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icono, size: 13, color: CEColors.textSecondary),
          const SizedBox(width: 4),
          Text(texto, style: const TextStyle(fontSize: 12, color: CEColors.textSecondary)),
        ],
      ),
    );
  }
}
