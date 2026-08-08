import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import 'ce_card.dart';

/// Tarjeta de estadistica (icono + valor grande + etiqueta), usada en
/// los encabezados de Ver Clientes / Ver Prestamos.
///
/// En escritorio Web (ver esEscritorioWeb) es mas compacta -- pensada
/// para telefono, se veia enorme estirada en una pantalla ancha.
class CeStatCard extends StatelessWidget {
  final IconData icono;
  final String valor;
  final String etiqueta;
  final Color color;

  const CeStatCard({
    super.key,
    required this.icono,
    required this.valor,
    required this.etiqueta,
    this.color = CEColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final compacta = esEscritorioWeb(context);
    return CeCard(
      padding: EdgeInsets.all(compacta ? 10 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, color: color, size: compacta ? 15 : 20),
          SizedBox(height: compacta ? 5 : 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor,
              maxLines: 1,
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: compacta ? 14 : 18, color: color),
            ),
          ),
          SizedBox(height: compacta ? 1 : 2),
          Text(etiqueta,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: compacta ? 9.5 : 11,
                  height: 1.15,
                  color: CEColors.textSecondary)),
        ],
      ),
    );
  }
}

/// Fila de tarjetas [CeStatCard] (u otro contenido similar). En
/// escritorio Web usa un ancho maximo fijo por tarjeta (no estira cada
/// una para llenar la pantalla, simplemente agrega mas columnas); en
/// mobile y Windows nativo se ve exactamente igual que antes
/// (GridView.count con los parametros que ya tenia cada pantalla).
class CeStatGrid extends StatelessWidget {
  final List<Widget> children;
  final int mobileCrossAxisCount;
  final double mobileChildAspectRatio;

  const CeStatGrid({
    super.key,
    required this.children,
    required this.mobileCrossAxisCount,
    required this.mobileChildAspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    if (esEscritorioWeb(context)) {
      return GridView.extent(
        maxCrossAxisExtent: 160,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.5,
        children: children,
      );
    }
    return GridView.count(
      crossAxisCount: mobileCrossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: mobileChildAspectRatio,
      children: children,
    );
  }
}
