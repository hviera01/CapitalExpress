import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/roles.dart';
import '../providers/web_tabs_provider.dart';
import '../services/web_refresh_service.dart';
import '../theme/app_theme.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'ce_web_sections.dart';

/// Chrome de escritorio Web: menu lateral desplegable + pestañas en
/// memoria (IndexedStack, ver WebTabsNotifier) en vez del menu
/// superior fijo + navegacion por ruta. Mismo patron que Super Color/
/// Variedades Lopsi: cambiar de seccion NO destruye ni recarga nada,
/// solo cambia que pestaña esta a la vista -- por eso es instantaneo,
/// sin el "salto"/parpadeo de una transicion de pantalla normal.
///
/// Cada pantalla dentro de una pestaña sigue usando go_router
/// (`context.push`) para navegar a detalles/formularios exactamente
/// igual que antes -- eso no cambia, solo la navegacion ENTRE
/// secciones (Clientes/Prestamos/Cobros/etc.) deja de pasar por el
/// router.
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
  bool _menuExpandido = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tabs = ref.read(webTabsProvider);
      if (tabs.tabs.isEmpty) {
        ref.read(webTabsProvider.notifier).abrir(WebTabItem(
              id: 'panel',
              titulo: widget.tituloInicial,
              icono: widget.iconoInicial,
              contenido: Builder(builder: widget.contenidoInicial),
              cerrable: false,
            ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(authProvider).usuario;
    final esAdmin = usuario?.rol == Roles.admin;
    final tabsState = ref.watch(webTabsProvider);

    final idsMenu = <String>[
      'panel',
      'clientes',
      'prestamos',
      'cobros',
      if (esAdmin) ...['solicitudes', 'reportes', 'usuarios', 'dispositivos'] else 'mis-pagos',
    ];

    return Scaffold(
      backgroundColor: CEColors.surface,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MenuLateral(
            expandido: _menuExpandido,
            idsMenu: idsMenu,
            tituloPanel: widget.tituloInicial,
            iconoPanel: widget.iconoInicial,
            idActivo: tabsState.tabs.isEmpty ? null : tabsState.tabs[tabsState.indiceActivo].id,
            nombreUsuario: usuario?.nombre ?? '',
            esAdmin: esAdmin,
            onToggle: () => setState(() => _menuExpandido = !_menuExpandido),
            onSeleccionar: (id) {
              if (id == 'panel') {
                ref.read(webTabsProvider.notifier).abrir(WebTabItem(
                      id: 'panel',
                      titulo: widget.tituloInicial,
                      icono: widget.iconoInicial,
                      contenido: Builder(builder: widget.contenidoInicial),
                      cerrable: false,
                    ));
              } else {
                abrirSeccionWeb(ref, id);
              }
            },
            onLogout: () {
              ref.read(webTabsProvider.notifier).limpiar();
              ref.read(authProvider.notifier).logout();
            },
          ),
          Expanded(
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
        ],
      ),
    );
  }
}

class _MenuLateral extends StatelessWidget {
  final bool expandido;
  final List<String> idsMenu;
  final String tituloPanel;
  final IconData iconoPanel;
  final String? idActivo;
  final String nombreUsuario;
  final bool esAdmin;
  final VoidCallback onToggle;
  final ValueChanged<String> onSeleccionar;
  final VoidCallback onLogout;

  const _MenuLateral({
    required this.expandido,
    required this.idsMenu,
    required this.tituloPanel,
    required this.iconoPanel,
    required this.idActivo,
    required this.nombreUsuario,
    required this.esAdmin,
    required this.onToggle,
    required this.onSeleccionar,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final ancho = expandido ? 220.0 : 68.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: ancho,
      color: CEColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 56,
            child: Row(
              mainAxisAlignment: expandido ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
              children: [
                if (expandido)
                  const Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Text(
                      'CAPITAL EXPRESS',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                IconButton(
                  icon: Icon(expandido ? Icons.chevron_left : Icons.menu, color: Colors.white70, size: 20),
                  tooltip: expandido ? 'Contraer menú' : 'Expandir menú',
                  onPressed: onToggle,
                ),
              ],
            ),
          ),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: idsMenu.map((id) {
                final titulo = id == 'panel' ? tituloPanel : ceSeccionesWeb[id]!.titulo;
                final icono = id == 'panel' ? iconoPanel : ceSeccionesWeb[id]!.icono;
                final activo = id == idActivo;
                final tile = Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onSeleccionar(id),
                    child: Container(
                      height: 44,
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      padding: EdgeInsets.symmetric(horizontal: expandido ? 12 : 0),
                      alignment: expandido ? Alignment.centerLeft : Alignment.center,
                      decoration: BoxDecoration(
                        color: activo ? Colors.white.withValues(alpha: 0.12) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icono, color: activo ? Colors.white : Colors.white60, size: 19),
                          if (expandido) ...[
                            const SizedBox(width: 12),
                            Text(titulo,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: activo ? Colors.white : Colors.white60,
                                  fontSize: 13,
                                  fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                                )),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
                return expandido ? tile : Tooltip(message: titulo, child: tile);
              }).toList(),
            ),
          ),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Column(
              children: [
                if (expandido)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12), shape: BoxShape.circle),
                          child: const Icon(Icons.person_outline, color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(nombreUsuario,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                              Text(esAdmin ? 'Administrador' : 'Cobrador',
                                  style: const TextStyle(color: Colors.white54, fontSize: 10.5)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  mainAxisAlignment: expandido ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
                  children: [
                    if (expandido)
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white54, size: 18),
                        tooltip: 'Actualizar app',
                        onPressed: () => limpiarCacheYRecargarWeb(),
                      ),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white70, size: 18),
                      tooltip: 'Cerrar sesión',
                      onPressed: onLogout,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
