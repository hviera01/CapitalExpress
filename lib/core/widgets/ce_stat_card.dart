import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import 'ce_card.dart';

/// Un dato de estadistica (icono + valor + etiqueta) -- ver [CeStatGrid].
class CeStatItem {
  final IconData icono;
  final String valor;
  final String etiqueta;
  final Color color;

  const CeStatItem({
    required this.icono,
    required this.valor,
    required this.etiqueta,
    this.color = CEColors.primary,
  });
}

/// Tarjeta de estadistica (icono + valor grande + etiqueta), usada en
/// mobile/Windows nativo -- ver [CeStatGrid].
class CeStatCard extends StatelessWidget {
  final CeStatItem item;

  const CeStatCard(this.item, {super.key});

  @override
  Widget build(BuildContext context) {
    return CeCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.icono, color: item.color, size: 20),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              item.valor,
              maxLines: 1,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: item.color),
            ),
          ),
          const SizedBox(height: 2),
          Text(item.etiqueta,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, height: 1.15, color: CEColors.textSecondary)),
        ],
      ),
    );
  }
}

/// Fila de estadisticas. En mobile/Windows nativo es una grilla de
/// tarjetas ([CeStatCard], GridView.count con los parametros que ya
/// tenia cada pantalla). En escritorio Web es una sola franja angosta
/// (icono + valor + etiqueta en linea, separados por espacio) -- las
/// tarjetas grandes se veian enormes e innecesarias en una pantalla
/// ancha, esto ocupa una fraccion del alto.
class CeStatGrid extends StatelessWidget {
  final List<CeStatItem> items;
  final int mobileCrossAxisCount;
  final double mobileChildAspectRatio;

  const CeStatGrid({
    super.key,
    required this.items,
    required this.mobileCrossAxisCount,
    required this.mobileChildAspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    if (esEscritorioWeb(context)) {
      return CeCard(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Wrap(
          spacing: 28,
          runSpacing: 12,
          children: items.map((it) => _StatInline(item: it)).toList(),
        ),
      );
    }
    return GridView.count(
      crossAxisCount: mobileCrossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: mobileChildAspectRatio,
      children: items.map((it) => CeStatCard(it)).toList(),
    );
  }
}

class _StatInline extends StatelessWidget {
  final CeStatItem item;

  const _StatInline({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(item.icono, size: 15, color: item.color),
        const SizedBox(width: 7),
        Text(item.valor,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: item.color)),
        const SizedBox(width: 6),
        Text(item.etiqueta, style: const TextStyle(fontSize: 11.5, color: CEColors.textSecondary)),
      ],
    );
  }
}
