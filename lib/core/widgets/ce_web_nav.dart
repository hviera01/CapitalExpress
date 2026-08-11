import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../utils/responsive.dart';

/// Navega a una pantalla secundaria (detalle/formulario) desde DENTRO
/// de una seccion. En escritorio Web usa el Navigator local de la
/// pestaña actual (ver CeWebShell/envolverConNavegador) para que la
/// pantalla de atras (la lista) siga viva y visible al volver, en vez
/// de taparla con una pantalla nueva encima de todo el shell. Mobile y
/// Windows siguen usando la ruta real de go_router (deep link, back
/// del sistema), sin ningun cambio.
Future<T?> irAPantalla<T>(
  BuildContext context, {
  required String ruta,
  required Widget pantalla,
  Object? extra,
}) {
  if (esEscritorioWeb(context)) {
    return Navigator.of(context).push<T>(_rutaLivianaWeb(pantalla));
  }
  return context.push<T>(ruta, extra: extra);
}

/// Transicion liviana SOLO para escritorio Web: la de Material por
/// defecto (deslizar + sombra) compone dos capas con transform durante
/// toda la animacion, y con listas grandes detras (Ver Prestamos/Ver
/// Clientes) eso se sentia pesado al entrar/salir de un detalle. Un
/// fundido corto es mucho mas barato de componer (solo opacidad, sin
/// transform) y se siente instantaneo.
PageRoute<T> _rutaLivianaWeb<T>(Widget pantalla) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => pantalla,
    transitionDuration: const Duration(milliseconds: 140),
    reverseTransitionDuration: const Duration(milliseconds: 120),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}
