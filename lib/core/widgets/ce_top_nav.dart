import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/roles.dart';
import '../services/web_refresh_service.dart';
import '../theme/app_theme.dart';
import '../../features/auth/providers/auth_provider.dart';

class _CeNavItem {
  final IconData icono;
  final String texto;
  final String ruta;

  const _CeNavItem(this.icono, this.texto, this.ruta);
}

/// Menu superior fijo para escritorio Web (ver esEscritorioWeb). Vive
/// arriba de TODAS las pantallas -- reemplaza el drawer oculto +
/// boton flotante (CeNavDrawer/CeMenuFab), que en una ventana ancha se
/// sentia como una app de tablet en vez de una app de escritorio.
class CeTopNav extends ConsumerWidget {
  const CeTopNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authProvider).usuario;
    final esAdmin = usuario?.rol == Roles.admin;
    final ubicacion = GoRouterState.of(context).uri.path;

    final items = <_CeNavItem>[
      _CeNavItem(Icons.home_outlined, 'Panel', esAdmin ? '/admin' : '/cobrador'),
      const _CeNavItem(Icons.people_outline, 'Clientes', '/clientes'),
      const _CeNavItem(Icons.account_balance_outlined, 'Préstamos', '/prestamos'),
      const _CeNavItem(Icons.notifications_outlined, 'Cobros', '/cobros'),
      if (esAdmin) ...[
        const _CeNavItem(Icons.assignment_outlined, 'Solicitudes', '/solicitudes'),
        const _CeNavItem(Icons.bar_chart_outlined, 'Reportes', '/reportes'),
        const _CeNavItem(Icons.manage_accounts_outlined, 'Usuarios', '/usuarios'),
      ] else
        const _CeNavItem(Icons.payments_outlined, 'Mis Pagos', '/reportes/cobros'),
    ];

    bool activo(_CeNavItem item) {
      if (item.ruta == '/admin' || item.ruta == '/cobrador') {
        return ubicacion == item.ruta;
      }
      return ubicacion == item.ruta || ubicacion.startsWith('${item.ruta}/');
    }

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: CEColors.border)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => context.go(esAdmin ? '/admin' : '/cobrador'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: CEColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.asset('assets/images/logo_capital_express.png', height: 22),
                ),
                const SizedBox(width: 10),
                const Text(
                  'CAPITAL EXPRESS',
                  style: TextStyle(
                    color: CEColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Row(
              children: items.map((item) => _NavButton(item: item, activo: activo(item))).toList(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: CEColors.textSecondary),
            tooltip: 'Actualizar app',
            onPressed: () => limpiarCacheYRecargarWeb(),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                usuario?.nombre ?? '',
                style: const TextStyle(
                  color: CEColors.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                esAdmin ? 'Administrador' : 'Cobrador',
                style: const TextStyle(color: CEColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.logout, color: CEColors.textSecondary),
            tooltip: 'Cerrar sesión',
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final _CeNavItem item;
  final bool activo;

  const _NavButton({required this.item, required this.activo});

  @override
  Widget build(BuildContext context) {
    final color = activo ? CEColors.primary : CEColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.go(item.ruta),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: activo ? CEColors.primary.withValues(alpha: 0.08) : null,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.icono, size: 17, color: color),
                const SizedBox(width: 7),
                Text(
                  item.texto,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: activo ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
