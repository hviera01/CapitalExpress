import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ce_card.dart';

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

/// Tarjeta con una DataTable adentro, para escritorio Web. A diferencia
/// de poner el DataTable suelto dentro de un SingleChildScrollView (que
/// deja la tabla mas angosta que la tarjeta cuando las columnas no
/// llenan el ancho disponible, con un espacio en blanco raro a la
/// derecha), esta version fuerza que la tabla ocupe COMO MINIMO el
/// ancho disponible -- ni mas angosta (queda "flotando" a la
/// izquierda) ni desbordada sin poder verse (ahi si aparece el scroll
/// horizontal, cuando de verdad hace falta).
class CeDataTableCard extends StatelessWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;

  const CeDataTableCard({super.key, required this.columns, required this.rows});

  @override
  Widget build(BuildContext context) {
    return CeCard(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowColor: ceTableHeadingRowColor,
                headingTextStyle: ceTableHeadingTextStyle,
                columns: columns,
                rows: rows,
              ),
            ),
          );
        },
      ),
    );
  }
}
