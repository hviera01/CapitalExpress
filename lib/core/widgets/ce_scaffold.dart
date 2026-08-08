import 'package:flutter/material.dart';

import '../utils/responsive.dart';
import 'ce_nav_drawer.dart';
import 'ce_top_nav.dart';

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
/// En escritorio Web (ver esEscritorioWeb) el menu lateral oculto +
/// boton flotante se reemplazan por CeTopNav, fijo arriba de toda la
/// pantalla -- asi no hace falta abrir un drawer para moverse de
/// seccion, como en una app de escritorio real. Mobile y la app nativa
/// de Windows no se tocan.
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
        appBar: null,
        floatingActionButton: floatingActionButton,
        body: Column(
          children: [
            const CeTopNav(),
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
/// debajo del menu superior fijo, en vez de una AppBar navy de ancho
/// completo pensada para telefono -- conserva todas sus acciones (no
/// se pierde nada), solo cambia como se ve.
class _BarraPagina extends StatelessWidget implements PreferredSizeWidget {
  final PreferredSizeWidget appBar;

  const _BarraPagina({required this.appBar});

  @override
  Widget build(BuildContext context) {
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
      child: appBar,
    );
  }

  @override
  Size get preferredSize => appBar.preferredSize;
}
