import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/roles.dart';
import '../theme/app_theme.dart';
import '../../features/auth/providers/auth_provider.dart';

/// Menu lateral con todas las secciones de la app, para poder saltar de
/// una pantalla a otra sin tener que volver primero al panel principal.
/// Lo trae CeScaffold en TODAS las pantallas (ver ce_scaffold.dart).
///
/// Ojo: cualquier AppBar que se pase a CeScaffold tiene que declarar su
/// propio `leading` (normalmente `const BackButton()`) explicitamente.
/// Si no lo hace, Flutter reemplaza automaticamente el boton de "atras"
/// por un icono de menu apenas el Scaffold tiene un `drawer` -- y el
/// boton de "atras" siempre tiene que quedar arriba, el menu se abre
/// solo con el flotante (CeMenuFab).
class CeNavDrawer extends ConsumerWidget {
  const CeNavDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authProvider).usuario;
    final esAdmin = usuario?.rol == Roles.admin;

    void ir(String ruta) {
      Navigator.of(context).pop();
      context.push(ruta);
    }

    return Drawer(
      backgroundColor: CEColors.primary,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'CAPITAL EXPRESS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                usuario?.nombre ?? '',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Divider(color: Colors.white24, height: 1),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _item(context, Icons.home_outlined, 'Panel Principal',
                      () => ir(esAdmin ? '/admin' : '/cobrador')),
                  _item(context, Icons.people_outline, 'Clientes', () => ir('/clientes')),
                  _item(context, Icons.account_balance_outlined, 'Préstamos',
                      () => ir('/prestamos')),
                  _item(context, Icons.notifications_outlined, 'Cobros', () => ir('/cobros')),
                  _item(context, Icons.bar_chart_outlined, 'Reportes', () => ir('/reportes')),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Divider(color: Colors.white24, height: 1),
            ),
            _item(
              context,
              Icons.logout,
              'Cerrar sesión',
              () {
                Navigator.of(context).pop();
                ref.read(authProvider.notifier).logout();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, IconData icono, String texto, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icono, color: Colors.white),
      title: Text(texto, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
    );
  }
}

/// Boton flotante que abre el CeNavDrawer, para tener acceso al menu
/// desde CUALQUIER pantalla (no solo los paneles de inicio). Vive en un
/// Stack sobre el body (no en el slot `floatingActionButton` de
/// Scaffold) para no chocar con el boton de accion propio de cada
/// pantalla (ej. "Nuevo cliente"), que sigue en su lugar de siempre.
class CeMenuFab extends StatelessWidget {
  const CeMenuFab({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'ce_menu_fab',
      backgroundColor: CEColors.primary,
      onPressed: () => Scaffold.of(context).openDrawer(),
      child: const Icon(Icons.menu, color: Colors.white),
    );
  }
}
