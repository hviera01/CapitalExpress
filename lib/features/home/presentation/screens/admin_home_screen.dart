import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/ce_dashed_card.dart';
import '../../../../core/widgets/ce_menu_card.dart';
import '../../../../core/widgets/ce_menu_row.dart';
import '../../../../core/widgets/ce_section_label.dart';
import '../../../../core/widgets/ce_shell.dart';
import '../../../auth/providers/auth_provider.dart';

const _colorSubtitulo = Color(0xFF2DD9B8);

class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  void _proximamente(BuildContext context, String modulo) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$modulo - próximamente')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authProvider).usuario;
    final escritorio = esEscritorio(context);
    final columnas = escritorio ? 4 : 2;

    return CeAppShell(
      subtituloApp: 'ADMIN PANEL',
      colorSubtitulo: _colorSubtitulo,
      tituloPagina: 'Panel Administrador',
      nombreUsuario: usuario?.nombre ?? '',
      rolUsuario: 'Administrador',
      onLogout: () => ref.read(authProvider.notifier).logout(),
      onNotificaciones: () => _proximamente(context, 'Notificaciones'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          escritorio ? 32 : 16,
          escritorio ? 0 : 16,
          escritorio ? 32 : 16,
          32,
        ),
        children: [
          CeMenuRow(
            icono: Icons.notifications_outlined,
            titulo: 'Ver Notificaciones',
            subtitulo: 'Centro de alertas crítico',
            chevron: true,
            onTap: () => _proximamente(context, 'Notificaciones'),
          ),
          const CeSectionLabel('Crear'),
          GridView.count(
            crossAxisCount: columnas,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.15,
            children: [
              CeMenuCard(
                icono: Icons.add,
                titulo: 'Crear Préstamo',
                subtitulo: 'Nueva solicitud',
                onTap: () => context.push('/prestamos/nuevo'),
              ),
              CeMenuCard(
                icono: Icons.person_add_alt_1_outlined,
                titulo: 'Crear Cliente',
                subtitulo: 'Alta de usuario',
                onTap: () => context.push('/clientes/nuevo'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CeMenuRow(
            icono: Icons.badge_outlined,
            titulo: 'Crear Usuario',
            subtitulo: 'Gestión interna',
            chevron: true,
            onTap: () => _proximamente(context, 'Crear Usuario'),
          ),
          const CeSectionLabel('Visualizar'),
          GridView.count(
            crossAxisCount: columnas,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.15,
            children: [
              CeMenuCard(
                oscuro: true,
                icono: Icons.forum_outlined,
                titulo: 'Solicitudes',
                subtitulo: '',
                onTap: () => _proximamente(context, 'Solicitudes'),
              ),
              CeMenuCard(
                icono: Icons.people_outline,
                titulo: 'Ver Clientes',
                subtitulo: '',
                onTap: () => context.push('/clientes'),
              ),
              CeMenuCard(
                icono: Icons.account_balance_outlined,
                titulo: 'Ver Préstamos',
                subtitulo: '',
                onTap: () => context.push('/prestamos'),
              ),
              CeMenuCard(
                icono: Icons.manage_accounts_outlined,
                titulo: 'Ver Usuarios',
                subtitulo: '',
                onTap: () => _proximamente(context, 'Ver Usuarios'),
              ),
            ],
          ),
          const CeSectionLabel('Historial'),
          CeMenuRow(
            icono: Icons.summarize_outlined,
            titulo: 'Reporte de Clientes',
            subtitulo: 'Filtros, resumen y exportar a PDF',
            chevron: true,
            onTap: () => context.push('/clientes/reporte'),
          ),
          const SizedBox(height: 12),
          CeMenuRow(
            icono: Icons.receipt_long_outlined,
            titulo: 'Historial de Pagos',
            subtitulo: 'Arqueo de caja y transacciones',
            chevron: true,
            onTap: () => _proximamente(context, 'Historial de Pagos'),
          ),
          const SizedBox(height: 12),
          CeMenuRow(
            icono: Icons.storage_outlined,
            titulo: 'Historial Global',
            subtitulo: 'Auditoría completa del sistema',
            chevron: true,
            onTap: () => _proximamente(context, 'Historial Global'),
          ),
          const CeSectionLabel('Estadísticas y herramientas'),
          CeMenuRow(
            icono: Icons.grid_view_outlined,
            titulo: 'Dashboard',
            subtitulo: 'Métricas en tiempo real',
            trailingIcon: Icons.trending_up,
            onTap: () => _proximamente(context, 'Dashboard'),
          ),
          const SizedBox(height: 12),
          CeDashedCard(
            onTap: () => _proximamente(context, 'Buscar Actualizaciones'),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration:
                      const BoxDecoration(color: CEColors.iconBadgeBg, shape: BoxShape.circle),
                  child: const Icon(Icons.history_toggle_off, color: CEColors.primary, size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Buscar Actualizaciones',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      SizedBox(height: 2),
                      Text('Revisar si hay una nueva versión de la app',
                          style: TextStyle(fontSize: 12, color: CEColors.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: CEColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'v1.0.0',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
