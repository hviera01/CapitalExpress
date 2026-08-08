import 'package:flutter/material.dart';

import '../utils/responsive.dart';
import 'ce_nav_drawer.dart';

/// Scaffold normal en mobile. En escritorio centra el contenido con un
/// ancho maximo (evita que un formulario/lista pensado para telefono se
/// vea estirado de borde a borde en una pantalla ancha) y le da mas
/// aire arriba.
///
/// Siempre trae el menu lateral (CeNavDrawer) y su boton flotante
/// (CeMenuFab, abajo a la izquierda) para poder saltar a cualquier
/// seccion desde cualquier pantalla. El `floatingActionButton` que le
/// pase cada pantalla (ej. "Nuevo cliente") sigue en su posicion de
/// siempre (abajo a la derecha) sin chocar con el del menu.
///
/// En escritorio Web (ver esEscritorioWeb) esta pantalla vive DENTRO
/// de una pestaña de CeWebShell (menu lateral + pestañas en memoria):
/// no hay que dibujar ningun menu propio aca, CeWebShell ya lo tiene.
/// Solo queda la franja angosta con titulo/acciones de la pantalla
/// (ver _BarraPagina) y el contenido a todo el ancho disponible.
/// Mobile y la app nativa de Windows no se tocan.
class CeScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final double maxWidth;

  const CeScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.maxWidth = 760,
  });

  @override
  Widget build(BuildContext context) {
    final escritorio = esEscritorio(context);
    final escritorioWeb = esEscritorioWeb(context);
    final anchoMaximo = escritorioWeb ? (maxWidth < 1400 ? 1400.0 : maxWidth) : maxWidth;
    final contenido = escritorio
        ? Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: anchoMaximo),
              child: body,
            ),
          )
        : body;

    if (escritorioWeb) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: null,
        floatingActionButton: floatingActionButton,
        body: Column(
          children: [
            if (appBar != null) _BarraPagina(appBar: appBar!),
            Expanded(child: contenido),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      drawer: const CeNavDrawer(),
      floatingActionButton: floatingActionButton,
      body: Stack(
        children: [
          contenido,
          const Positioned(left: 16, bottom: 16, child: CeMenuFab()),
        ],
      ),
    );
  }
}

/// En escritorio Web, el AppBar de cada pantalla (titulo + acciones
/// como "Exportar PDF"/"Refrescar") se muestra como una franja angosta
/// en vez de una AppBar navy de ancho completo pensada para telefono
/// -- conserva todas sus acciones (no se pierde nada), solo cambia
/// como se ve.
///
/// El boton de "atras" solo se muestra si de verdad hay algo para
/// volver (`Navigator.canPop`): las pantallas de nivel superior
/// (Clientes/Prestamos/etc.) viven como pestañas de CeWebShell, sin
/// pasar por el Navigator para abrirse, asi que ahi no hay nada que
/// hacer pop y el boton se saca (quedaba sin responder al tocarlo).
/// Un detalle/formulario abierto con `context.push` SI tiene algo
/// para volver, asi que ahi el boton se deja tal cual.
class _BarraPagina extends StatelessWidget implements PreferredSizeWidget {
  final PreferredSizeWidget appBar;

  const _BarraPagina({required this.appBar});

  @override
  Widget build(BuildContext context) {
    final barra = appBar;
    final puedeVolver = Navigator.canPop(context);
    final ajustada = barra is AppBar
        ? AppBar(
            title: barra.title,
            actions: barra.actions,
            bottom: barra.bottom,
            backgroundColor: barra.backgroundColor,
            leading: puedeVolver ? barra.leading : null,
            automaticallyImplyLeading: puedeVolver,
          )
        : barra;

    return Theme(
      data: Theme.of(context).copyWith(
        appBarTheme: Theme.of(context).appBarTheme.copyWith(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0F172A),
              elevation: 0,
              iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
              titleTextStyle: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              shape: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
      ),
      child: ajustada,
    );
  }

  @override
  Size get preferredSize => appBar.preferredSize;
}
