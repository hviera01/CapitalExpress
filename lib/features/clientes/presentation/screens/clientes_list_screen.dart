import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/roles.dart';
import '../../../../core/models/cliente_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/imagen_red_network.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/clientes_provider.dart';

class ClientesListScreen extends ConsumerWidget {
  const ClientesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authProvider).usuario;
    final esAdmin = usuario?.rol == Roles.admin;
    final cobradorUid = esAdmin ? null : usuario?.uid;

    final clientesAsync = ref.watch(clientesStreamProvider(cobradorUid));
    final busqueda = ref.watch(busquedaClientesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(esAdmin ? 'Ver Clientes' : 'Mis Clientes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/clientes/nuevo'),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Nuevo cliente'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre, identidad o telefono',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => ref.read(busquedaClientesProvider.notifier).state = v,
            ),
          ),
          Expanded(
            child: clientesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error al cargar clientes: $e')),
              data: (clientes) {
                final filtrados = filtrarClientes(clientes, busqueda);
                if (filtrados.isEmpty) {
                  return const Center(child: Text('No hay clientes'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  itemCount: filtrados.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _ClienteTile(cliente: filtrados[i]),
                );
              },
            ),
          ),
        ],
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
      child: ListTile(
        contentPadding: const EdgeInsets.all(8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 48,
            height: 48,
            child: cliente.fotoClienteUrl.isNotEmpty
                ? ImagenRedNetwork(url: cliente.fotoClienteUrl)
                : const ColoredBox(
                    color: CEColors.surface,
                    child: Icon(Icons.person_outline, color: CEColors.textSecondary),
                  ),
          ),
        ),
        title: Text(cliente.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(cliente.telefono),
        trailing: cliente.tienePrestamo
            ? const Chip(
                label: Text('Con prestamo', style: TextStyle(fontSize: 11)),
                backgroundColor: Color(0x1A007AFF),
                side: BorderSide.none,
              )
            : null,
        onTap: () => context.push('/clientes/${cliente.id}'),
      ),
    );
  }
}
