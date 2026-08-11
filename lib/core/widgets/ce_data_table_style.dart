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
///
/// `rows` completo se recibe siempre entero (los que llaman a este
/// widget no cambian), pero SOLO se monta de a `_tamanoPagina` filas por
/// vez -- Flutter's DataTable no es lazy, arma TODO el arbol (celdas +
/// PopupMenuButton de cada fila) aunque no se vea en pantalla, y con
/// listas grandes (cientos de prestamos/clientes) eso es lo que hacia
/// sentir pesada la carga, el scroll, y hasta la animacion de
/// entrar/salir a un detalle (la pantalla de atras queda de todos modos
/// en el arbol mientras transiciona). Ver "Mostrar más" al pie.
class CeDataTableCard extends StatefulWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;

  const CeDataTableCard({super.key, required this.columns, required this.rows});

  @override
  State<CeDataTableCard> createState() => _CeDataTableCardState();
}

class _CeDataTableCardState extends State<CeDataTableCard> {
  static const _tamanoPagina = 40;
  int _visibles = _tamanoPagina;

  @override
  void didUpdateWidget(covariant CeDataTableCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rows.length != oldWidget.rows.length) {
      _visibles = _tamanoPagina;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hayMas = widget.rows.length > _visibles;
    final filasAMostrar = hayMas ? widget.rows.sublist(0, _visibles) : widget.rows;

    return CeCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowColor: ceTableHeadingRowColor,
                    headingTextStyle: ceTableHeadingTextStyle,
                    columns: widget.columns,
                    rows: filasAMostrar,
                  ),
                ),
              );
            },
          ),
          if (hayMas)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: TextButton(
                  onPressed: () =>
                      setState(() => _visibles = (_visibles + _tamanoPagina).clamp(0, widget.rows.length)),
                  child: Text('Mostrar más (${widget.rows.length - _visibles} de ${widget.rows.length})'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
