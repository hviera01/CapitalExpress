import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/roles.dart';
import '../providers/web_tabs_provider.dart';
import '../services/web_refresh_service.dart';
import '../theme/app_theme.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/tickets/providers/tickets_provider.dart';
import 'ce_web_sections.dart';

/// Chrome de escritorio Web: barra superior fija (marca, usuario,
/// actualizar, cerrar sesion) + menu lateral desplegable EN OVERLAY
/// (no empuja/redimensiona el contenido, por eso abrir/cerrar es
/// instantaneo) + pestañas en memoria (IndexedStack, ver
/// WebTabsNotifier). Mismo patron que Super Color/Variedades Lopsi:
/// cambiar de seccion NO destruye ni recarga nada, solo cambia que
/// pestaña esta a la vista.
///
/// Cada pantalla dentro de una pestaña tiene su PROPIO Navigator local
/// (ver _envolverConNavegador): un detalle/formulario abierto desde
/// adentro de una pestaña se apila ahi mismo, sin tapar el menu ni la
/// barra de pestañas, y al volver la lista de atras sigue exactamente
/// como estaba (ver ce_web_nav.dart).
class CeWebShell extends ConsumerStatefulWidget {
  final String tituloInicial;
  final IconData iconoInicial;
  final WidgetBuilder contenidoInicial;

  const CeWebShell({
    super.key,
    required this.tituloInicial,
    required this.iconoInicial,
    required this.contenidoInicial,
  });

  @override
  ConsumerState<CeWebShell> createState() => _CeWebShellState();
}

class _CeWebShellState extends ConsumerState<CeWebShell> {
  bool _menuAbierto = false;

  WebTabItem _tabPanel() => WebTabItem(
        id: 'panel',
        titulo: widget.tituloInicial,
        icono: widget.iconoInicial,
        contenido: envolverConNavegador(widget.contenidoInicial),
        cerrable: false,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tabs = ref.read(webTabsProvider);
      if (tabs.tabs.isEmpty) {
        ref.read(webTabsProvider.notifier).abrir(_tabPanel());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(authProvider).usuario;
    final esAdmin = Roles.esAdminOEquivalente(usuario?.rol);
    final tabsState = ref.watch(webTabsProvider);

    final idsMenu = <String>[
      'panel',
      'clientes',
      'prestamos',
      'cobros',
      if (esAdmin) ...['solicitudes', 'reportes', 'usuarios', 'dispositivos', 'bitacora'] else 'mis-pagos',
      'tickets',
    ];

    return Scaffold(
      backgroundColor: CEColors.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BarraSuperior(
            menuAbierto: _menuAbierto,
            nombreUsuario: usuario?.nombre ?? '',
            esAdmin: esAdmin,
            onToggleMenu: () => setState(() => _menuAbierto = !_menuAbierto),
            onLogout: () {
              ref.read(webTabsProvider.notifier).limpiar();
              ref.read(authProvider.notifier).logout();
            },
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (tabsState.tabs.length > 1)
                        _BarraPestanas(
                          tabs: tabsState.tabs,
                          indiceActivo: tabsState.indiceActivo,
                          onSeleccionar: (i) => ref.read(webTabsProvider.notifier).seleccionar(i),
                          onCerrar: (id) => ref.read(webTabsProvider.notifier).cerrar(id),
                        ),
                      Expanded(
                        child: tabsState.tabs.isEmpty
                            ? const SizedBox()
                            : IndexedStack(
                                index: tabsState.indiceActivo,
                                children: tabsState.tabs.map((t) => t.contenido).toList(),
                              ),
                      ),
                    ],
                  ),
                ),
                if (_menuAbierto) ...[
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _menuAbierto = false),
                      child: Container(color: Colors.black.withValues(alpha: 0.15)),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Material(
                      elevation: 8,
                      child: _MenuLateral(
                        idsMenu: idsMenu,
                        tituloPanel: widget.tituloInicial,
                        iconoPanel: widget.iconoInicial,
                        idActivo: tabsState.tabs.isEmpty ? null : tabsState.tabs[tabsState.indiceActivo].id,
                        onSeleccionar: (id) {
                          if (id == 'panel') {
                            ref.read(webTabsProvider.notifier).abrir(_tabPanel());
                          } else {
                            abrirSeccionWeb(ref, id);
                          }
                          setState(() => _menuAbierto = false);
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Cada pestaña vive con su propio Navigator: eso hace que un
/// detalle/formulario abierto DESDE ADENTRO de esa pestaña (ver
/// irAPantalla en ce_web_nav.dart) se apile localmente, en vez de
/// taparlo todo -- la barra de pestañas y el menu lateral se ven
/// siempre, y al volver la pantalla de atras esta intacta.
Widget envolverConNavegador(WidgetBuilder construir) {
  return Navigator(
    onGenerateRoute: (settings) => MaterialPageRoute(builder: construir, settings: settings),
  );
}

class _BarraSuperior extends StatelessWidget {
  final bool menuAbierto;
  final String nombreUsuario;
  final bool esAdmin;
  final VoidCallback onToggleMenu;
  final VoidCallback onLogout;

  const _BarraSuperior({
    required this.menuAbierto,
    required this.nombreUsuario,
    required this.esAdmin,
    required this.onToggleMenu,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      color: CEColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(menuAbierto ? Icons.menu_open : Icons.menu, color: Colors.white, size: 22),
            tooltip: menuAbierto ? 'Cerrar menú' : 'Abrir menú',
            onPressed: onToggleMenu,
          ),
          const SizedBox(width: 4),
          const Text(
            'CAPITAL EXPRESS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          Container(
            width: 28,
            height: 28,
            decoration:
                BoxDecoration(color: Colors.white.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: const Icon(Icons.person_outline, color: Colors.white, size: 15),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(nombreUsuario,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              Text(esAdmin ? 'Administrador' : 'Cobrador',
                  style: const TextStyle(color: Colors.white54, fontSize: 10.5)),
            ],
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54, size: 19),
            tooltip: 'Actualizar app',
            onPressed: () => limpiarCacheYRecargarWeb(),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70, size: 19),
            tooltip: 'Cerrar sesión',
            onPressed: onLogout,
          ),
        ],
      ),
    );
  }
}

class _MenuLateral extends ConsumerWidget {
  final List<String> idsMenu;
  final String tituloPanel;
  final IconData iconoPanel;
  final String? idActivo;
  final ValueChanged<String> onSeleccionar;

  const _MenuLateral({
    required this.idsMenu,
    required this.tituloPanel,
    required this.iconoPanel,
    required this.idActivo,
    required this.onSeleccionar,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsNoLeidos = ref.watch(ticketsNoLeidosProvider).value ?? 0;
    return Container(
      width: 230,
      color: CEColors.primary,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: idsMenu.map((id) {
          final titulo = id == 'panel' ? tituloPanel : ceSeccionesWeb[id]!.titulo;
          final icono = id == 'panel' ? iconoPanel : ceSeccionesWeb[id]!.icono;
          final activo = id == idActivo;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSeleccionar(id),
              child: Container(
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: activo ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icono, color: activo ? Colors.white : Colors.white60, size: 19),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(titulo,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: activo ? Colors.white : Colors.white60,
                            fontSize: 13,
                            fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                          )),
                    ),
                    if (id == 'tickets' && ticketsNoLeidos > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration:
                            BoxDecoration(color: CEColors.danger, borderRadius: BorderRadius.circular(20)),
                        child: Text('$ticketsNoLeidos',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BarraPestanas extends StatelessWidget {
  final List<WebTabItem> tabs;
  final int indiceActivo;
  final ValueChanged<int> onSeleccionar;
  final ValueChanged<String> onCerrar;

  const _BarraPestanas({
    required this.tabs,
    required this.indiceActivo,
    required this.onSeleccionar,
    required this.onCerrar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: CEColors.border)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            _Pestana(
              tab: tabs[i],
              activa: i == indiceActivo,
              onTap: () => onSeleccionar(i),
              onCerrar: tabs[i].cerrable ? () => onCerrar(tabs[i].id) : null,
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _Pestana extends StatelessWidget {
  final WebTabItem tab;
  final bool activa;
  final VoidCallback onTap;
  final VoidCallback? onCerrar;

  const _Pestana({required this.tab, required this.activa, required this.onTap, this.onCerrar});

  @override
  Widget build(BuildContext context) {
    final color = activa ? CEColors.primary : Colors.grey.shade600;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: activa ? CEColors.primary.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: activa ? Border.all(color: CEColors.primary.withValues(alpha: 0.25)) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(tab.icono, size: 14, color: color),
              const SizedBox(width: 6),
              Text(tab.titulo,
                  style: TextStyle(
                      fontSize: 12.5, color: color, fontWeight: activa ? FontWeight.w700 : FontWeight.w500)),
              if (onCerrar != null) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: onCerrar,
                  borderRadius: BorderRadius.circular(10),
                  child: Icon(Icons.close, size: 13, color: color.withValues(alpha: 0.7)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
