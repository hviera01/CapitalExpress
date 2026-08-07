import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/providers/auth_provider.dart';

class _ModuloAdmin {
  final String titulo;
  final IconData icono;

  const _ModuloAdmin(this.titulo, this.icono);
}

const _modulos = [
  _ModuloAdmin('Ver Clientes', Icons.people_outline),
  _ModuloAdmin('Ver Prestamos', Icons.request_page_outlined),
  _ModuloAdmin('Historial de Pagos', Icons.receipt_long_outlined),
  _ModuloAdmin('Historial de Prestamos', Icons.history_outlined),
  _ModuloAdmin('Notificaciones y Cobro', Icons.notifications_outlined),
  _ModuloAdmin('Solicitudes', Icons.assignment_outlined),
  _ModuloAdmin('Ver Usuarios', Icons.manage_accounts_outlined),
  _ModuloAdmin('Dashboard', Icons.bar_chart_outlined),
];

class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authProvider).usuario;

    return Scaffold(
      appBar: AppBar(
        title: Text('Hola, ${usuario?.nombre ?? ''}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesion',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.1,
        ),
        itemCount: _modulos.length,
        itemBuilder: (context, i) {
          final m = _modulos[i];
          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${m.titulo} - proximamente')),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(m.icono, size: 32, color: CEColors.primary),
                    const SizedBox(height: 12),
                    Text(
                      m.titulo,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
