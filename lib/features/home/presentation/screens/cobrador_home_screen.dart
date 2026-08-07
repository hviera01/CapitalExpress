import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ce_app_bar.dart';
import '../../../../core/widgets/ce_menu_card.dart';
import '../../../../core/widgets/ce_menu_row.dart';
import '../../../../core/widgets/ce_section_label.dart';
import '../../../auth/providers/auth_provider.dart';

const _colorSubtitulo = Color(0xFF2DD9B8);

class CobradorHomeScreen extends ConsumerWidget {
  const CobradorHomeScreen({super.key});

  void _proximamente(BuildContext context, String modulo) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$modulo - próximamente')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authProvider).usuario;

    return Scaffold(
      backgroundColor: CEColors.surface,
      appBar: CeAppBar(
        titulo: 'Capital Express',
        subtitulo: 'PANEL DE COBRANZA',
        colorSubtitulo: _colorSubtitulo,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {},
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16, left: 4),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: CEColors.iconBadgeBg,
              child: Icon(Icons.person, color: CEColors.primary, size: 18),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: CEColors.primary,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  usuario?.nombre ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Divider(color: Colors.white24, height: 1),
              ListTile(
                iconColor: Colors.white,
                textColor: Colors.white,
                leading: const Icon(Icons.logout),
                title: const Text('Cerrar sesión'),
                onTap: () => ref.read(authProvider.notifier).logout(),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: CEColors.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.person_outline, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('¡Bienvenido!',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                        const SizedBox(height: 2),
                        Text(usuario?.nombre ?? '',
                            style: const TextStyle(color: CEColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        color: CEColors.onlineDot,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: CEColors.border),
          ),
          const CeSectionLabel('Opciones principales'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.15,
            children: [
              CeMenuCard(
                icono: Icons.person_add_alt_1_outlined,
                titulo: 'Registrar Cliente',
                subtitulo: 'Alta de usuario',
                onTap: () => context.push('/clientes/nuevo'),
              ),
              CeMenuCard(
                icono: Icons.people_outline,
                titulo: 'Ver Clientes',
                subtitulo: 'Mi cartera',
                onTap: () => context.push('/clientes'),
              ),
              CeMenuCard(
                icono: Icons.account_balance_outlined,
                titulo: 'Ver Préstamos',
                subtitulo: 'Detalle créditos',
                onTap: () => _proximamente(context, 'Ver Préstamos'),
              ),
              CeMenuCard(
                icono: Icons.payments_outlined,
                titulo: 'Mis Pagos',
                subtitulo: 'Recaudación',
                onTap: () => _proximamente(context, 'Mis Pagos'),
              ),
            ],
          ),
          const CeSectionLabel('Gestión y servicios'),
          CeMenuRow(
            icono: Icons.add_card_outlined,
            titulo: 'Solicitar Préstamo',
            subtitulo: 'Crear nueva solicitud',
            chevron: true,
            onTap: () => _proximamente(context, 'Solicitar Préstamo'),
          ),
          const SizedBox(height: 12),
          CeMenuRow(
            icono: Icons.notifications_outlined,
            titulo: 'Ver Notificaciones',
            subtitulo: 'Revisar mensajes y alertas',
            chevron: true,
            onTap: () => _proximamente(context, 'Notificaciones'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
