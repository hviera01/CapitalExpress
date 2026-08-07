import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/ce_menu_card.dart';
import '../../../../core/widgets/ce_menu_row.dart';
import '../../../../core/widgets/ce_section_label.dart';
import '../../../../core/widgets/ce_shell.dart';
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
    final escritorio = esEscritorio(context);
    final columnas = escritorio ? 4 : 2;

    return CeAppShell(
      subtituloApp: 'PANEL DE COBRANZA',
      colorSubtitulo: _colorSubtitulo,
      tituloPagina: 'Panel de Cobranza',
      nombreUsuario: usuario?.nombre ?? '',
      rolUsuario: 'Cobrador',
      onLogout: () => ref.read(authProvider.notifier).logout(),
      body: ListView(
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
          const CeSectionLabel('Opciones principales'),
          GridView.count(
            crossAxisCount: columnas,
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
                onTap: () => context.push('/prestamos'),
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
            titulo: 'Cobros',
            subtitulo: 'Cuotas vencidas y próximas',
            chevron: true,
            onTap: () => context.push('/cobros'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
