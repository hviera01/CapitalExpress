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
    final contenido = escritorio
        ? Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: body,
            ),
          )
        : body;

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
