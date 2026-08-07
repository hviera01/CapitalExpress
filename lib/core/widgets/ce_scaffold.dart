import 'package:flutter/material.dart';

import '../utils/responsive.dart';

/// Scaffold normal en mobile. En escritorio centra el contenido con un
/// ancho maximo (evita que un formulario/lista pensado para telefono se
/// vea estirado de borde a borde en una pantalla ancha) y le da mas
/// aire arriba.
class CeScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? drawer;
  final double maxWidth;

  const CeScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.drawer,
    this.maxWidth = 760,
  });

  @override
  Widget build(BuildContext context) {
    final escritorio = esEscritorio(context);

    return Scaffold(
      appBar: appBar,
      drawer: drawer,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      body: escritorio
          ? Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: body,
              ),
            )
          : body,
    );
  }
}
