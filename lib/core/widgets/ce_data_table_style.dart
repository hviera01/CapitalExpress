import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Estilo comun para todas las DataTable de escritorio Web (mismo
/// encabezado navy que ya se usaba en Reporte de Clientes), para que
/// todas las tablas de la app se vean iguales.
final WidgetStateProperty<Color?> ceTableHeadingRowColor =
    WidgetStateProperty.all(CEColors.primary);

const TextStyle ceTableHeadingTextStyle =
    TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12);

Widget ceTableBadge(String texto, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(texto,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
  );
}
