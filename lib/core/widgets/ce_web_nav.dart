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
    return Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => pantalla));
  }
  return context.push<T>(ruta, extra: extra);
}
