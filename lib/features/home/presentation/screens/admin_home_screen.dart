import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/ce_dashed_card.dart';
import '../../../../core/widgets/ce_menu_card.dart';
import '../../../../core/widgets/ce_menu_row.dart';
import '../../../../core/widgets/ce_panel_escritorio.dart';
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
      onNotificaciones: () => context.push('/cobros'),
      body: esEscritorioWeb(context) ? _cuerpoEscritorio(context) : ListView(
        padding: EdgeInsets.fromLTRB(
          escritorio ? 32 : 16,
          escritorio ? 0 : 16,
          escritorio ? 32 : 16,
          32,
        ),
        children: [
          if (!escritorio) ...[
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('¡Bienvenido!',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                            const SizedBox(height: 2),
                            Text(
                              usuario?.nombre ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(color: CEColors.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
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
          ],
          CeMenuRow(
            icono: Icons.notifications_outlined,
            titulo: 'Cobros',
            subtitulo: 'Cuotas vencidas y próximas',
            chevron: true,
            onTap: () => context.push('/cobros'),
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
            onTap: () => context.push('/usuarios/nuevo'),
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
                onTap: () => context.push('/solicitudes'),
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
                onTap: () => context.push('/usuarios'),
              ),
              CeMenuCard(
                icono: Icons.devices_outlined,
                titulo: 'Dispositivos',
                subtitulo: '',
                onTap: () => context.push('/dispositivos'),
              ),
            ],
          ),
          const CeSectionLabel('Reportes'),
          CeMenuRow(
            icono: Icons.summarize_outlined,
            titulo: 'Reportes',
            subtitulo: 'Clientes, préstamos, cobros y dashboard',
            chevron: true,
            onTap: () => context.push('/reportes'),
          ),
          // "Buscar Actualizaciones" no aplica en Web (ver
          // ActualizacionService.aplica) -- ahi esa tarjeta era solo un
          // adorno sin funcion real, se saca del todo.
          if (!kIsWeb) ...[
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
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Panel de escritorio Web: accesos rapidos en forma de botones
  /// chicos tipo barra de herramientas (ver CePanelSeccionEscritorio),
  /// en vez de la grilla de tarjetas grandes de mobile/Windows -- esa
  /// grilla, aunque con mas columnas, seguia siendo un "launcher de
  /// celular" reacomodado.
  Widget _cuerpoEscritorio(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
      children: [
        CePanelSeccionEscritorio(
          titulo: 'ACCIONES RÁPIDAS',
          acciones: [
            CePanelAccion(
                icono: Icons.notifications_outlined,
                titulo: 'Cobros',
                onTap: () => context.push('/cobros')),
            CePanelAccion(
                icono: Icons.add,
                titulo: 'Crear Préstamo',
                onTap: () => context.push('/prestamos/nuevo')),
            CePanelAccion(
                icono: Icons.person_add_alt_1_outlined,
                titulo: 'Crear Cliente',
                onTap: () => context.push('/clientes/nuevo')),
            CePanelAccion(
                icono: Icons.badge_outlined,
                titulo: 'Crear Usuario',
                onTap: () => context.push('/usuarios/nuevo')),
          ],
        ),
        const SizedBox(height: 24),
        CePanelSeccionEscritorio(
          titulo: 'EXPLORAR',
          acciones: [
            CePanelAccion(
                icono: Icons.forum_outlined,
                titulo: 'Solicitudes',
                onTap: () => context.push('/solicitudes')),
            CePanelAccion(
                icono: Icons.people_outline,
                titulo: 'Ver Clientes',
                onTap: () => context.push('/clientes')),
            CePanelAccion(
                icono: Icons.account_balance_outlined,
                titulo: 'Ver Préstamos',
                onTap: () => context.push('/prestamos')),
            CePanelAccion(
                icono: Icons.manage_accounts_outlined,
                titulo: 'Ver Usuarios',
                onTap: () => context.push('/usuarios')),
            CePanelAccion(
                icono: Icons.devices_outlined,
                titulo: 'Dispositivos',
                onTap: () => context.push('/dispositivos')),
            CePanelAccion(
                icono: Icons.summarize_outlined,
                titulo: 'Reportes',
                onTap: () => context.push('/reportes')),
          ],
        ),
      ],
    );
  }
}
