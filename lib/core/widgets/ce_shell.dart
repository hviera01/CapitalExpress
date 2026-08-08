import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import 'ce_app_bar.dart';
import 'ce_nav_drawer.dart';
import 'ce_top_nav.dart';

/// Chrome de las pantallas "home" (Panel Admin / Panel Cobrador).
///
/// Mobile: barra navy arriba + drawer, igual que antes.
/// Escritorio Web: menu superior fijo (CeTopNav, igual que el resto de
/// la app) y el contenido usando el ancho disponible.
/// Escritorio nativo (Windows): rail lateral navy fijo (marca +
/// usuario + salir), sin tocar.
class CeAppShell extends StatelessWidget {
  final String subtituloApp;
  final Color colorSubtitulo;
  final String tituloPagina;
  final String nombreUsuario;
  final String rolUsuario;
  final VoidCallback onLogout;
  final VoidCallback? onNotificaciones;
  final Widget body;

  const CeAppShell({
    super.key,
    required this.subtituloApp,
    required this.colorSubtitulo,
    required this.tituloPagina,
    required this.nombreUsuario,
    required this.rolUsuario,
    required this.onLogout,
    required this.body,
    this.onNotificaciones,
  });

  @override
  Widget build(BuildContext context) {
    if (esEscritorioWeb(context)) {
      // Sin _HeaderEscritorio aca: era una franja con el titulo de la
      // pagina + la campana de notificaciones que solo empujaba el
      // contenido mas abajo -- el titulo ya es redundante con la
      // pestaña activa de CeTopNav, y la campana se movio al propio
      // CeTopNav (siempre visible, no solo en el panel).
      return Scaffold(
        backgroundColor: CEColors.surface,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CeTopNav(),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1600),
                  child: body,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (esEscritorio(context)) {
      return Scaffold(
        backgroundColor: CEColors.surface,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Sidebar(
              subtituloApp: subtituloApp,
              colorSubtitulo: colorSubtitulo,
              nombreUsuario: nombreUsuario,
              rolUsuario: rolUsuario,
              onLogout: onLogout,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HeaderEscritorio(
                    titulo: tituloPagina,
                    onNotificaciones: onNotificaciones,
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1180),
                        child: body,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: CEColors.surface,
      appBar: CeAppBar(
        titulo: 'Capital Express',
        subtitulo: subtituloApp,
        colorSubtitulo: colorSubtitulo,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          if (onNotificaciones != null)
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.white),
              onPressed: onNotificaciones,
            ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Cerrar sesión',
            onPressed: onLogout,
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: const CeNavDrawer(),
      body: body,
    );
  }
}

class _Sidebar extends StatelessWidget {
  final String subtituloApp;
  final Color colorSubtitulo;
  final String nombreUsuario;
  final String rolUsuario;
  final VoidCallback onLogout;

  const _Sidebar({
    required this.subtituloApp,
    required this.colorSubtitulo,
    required this.nombreUsuario,
    required this.rolUsuario,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: CEColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Image.asset('assets/images/logo_capital_express.png', height: 34),
          ),
          const SizedBox(height: 10),
          Text(
            subtituloApp,
            style: TextStyle(
              color: colorSubtitulo,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 40),
          const Spacer(),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.12)),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_outline, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombreUsuario,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      rolUsuario,
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onLogout,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.logout, size: 16),
              label: const Text('Cerrar sesión'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderEscritorio extends StatelessWidget {
  final String titulo;
  final VoidCallback? onNotificaciones;

  const _HeaderEscritorio({required this.titulo, this.onNotificaciones});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 12),
      child: Row(
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: CEColors.textPrimary,
            ),
          ),
          const Spacer(),
          if (onNotificaciones != null)
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: CEColors.textPrimary),
              onPressed: onNotificaciones,
            ),
        ],
      ),
    );
  }
}
