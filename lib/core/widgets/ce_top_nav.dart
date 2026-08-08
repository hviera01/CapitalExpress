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
///
/// Mismo patron de dos franjas que usan Super Color y Variedades Lopsi
/// (ver app_shell.dart de esos proyectos): una franja superior con el
/// color de marca (aca, azul marino) para el nombre de la app y el
/// usuario, y debajo una franja de pestañas -- solo que aca cada
/// "pestaña" navega por ruta (go_router) en vez de abrir un tab nuevo
/// en memoria.
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
        const _CeNavItem(Icons.devices_outlined, 'Dispositivos', '/dispositivos'),
      ] else
        const _CeNavItem(Icons.payments_outlined, 'Mis Pagos', '/reportes/cobros'),
    ];

    bool activo(_CeNavItem item) {
      if (item.ruta == '/admin' || item.ruta == '/cobrador') {
        return ubicacion == item.ruta;
      }
      return ubicacion == item.ruta || ubicacion.startsWith('${item.ruta}/');
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          color: CEColors.primary,
          child: Row(
            children: [
              InkWell(
                onTap: () => context.go(esAdmin ? '/admin' : '/cobrador'),
                child: const Text(
                  'CAPITAL EXPRESS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white70),
                tooltip: 'Actualizar app',
                onPressed: () => limpiarCacheYRecargarWeb(),
              ),
              const SizedBox(width: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    usuario?.nombre ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    esAdmin ? 'Administrador' : 'Cobrador',
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white70),
                tooltip: 'Cerrar sesión',
                onPressed: () => ref.read(authProvider.notifier).logout(),
              ),
            ],
          ),
        ),
        Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: CEColors.border)),
          ),
          child: Row(
            children: items.map((item) => _TabPestana(item: item, activo: activo(item))).toList(),
          ),
        ),
      ],
    );
  }
}

/// Boton de "pestaña" para el menu superior -- mismo estilo pill que
/// usan Super Color/Variedades Lopsi (relleno tenue + borde + texto en
/// el color de marca cuando esta activa, gris cuando no).
class _TabPestana extends StatelessWidget {
  final _CeNavItem item;
  final bool activo;

  const _TabPestana({required this.item, required this.activo});

  @override
  Widget build(BuildContext context) {
    final color = activo ? CEColors.primary : Colors.grey.shade600;
    return Padding(
      padding: const EdgeInsets.only(right: 6, top: 6, bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.go(item.ruta),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: activo ? CEColors.primary.withValues(alpha: 0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: activo
                  ? Border.all(color: CEColors.primary.withValues(alpha: 0.25))
                  : Border.all(color: Colors.transparent),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.icono, size: 16, color: color),
                const SizedBox(width: 7),
                Text(
                  item.texto,
                  style: TextStyle(
                    color: color,
                    fontSize: 12.5,
                    fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
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
