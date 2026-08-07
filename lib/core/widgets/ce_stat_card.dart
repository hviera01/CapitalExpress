import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ce_card.dart';

/// Tarjeta de estadistica (icono + valor grande + etiqueta), usada en
/// los encabezados de Ver Clientes / Ver Prestamos.
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
    return CeCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, color: color, size: 20),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor,
              maxLines: 1,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: color),
            ),
          ),
          const SizedBox(height: 2),
          Text(etiqueta,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, height: 1.15, color: CEColors.textSecondary)),
        ],
      ),
    );
  }
}
