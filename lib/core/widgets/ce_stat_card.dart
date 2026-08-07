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
        children: [
          Icon(icono, color: color, size: 20),
          const SizedBox(height: 10),
          Text(
            valor,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: color),
          ),
          const SizedBox(height: 2),
          Text(etiqueta, style: const TextStyle(fontSize: 12, color: CEColors.textSecondary)),
        ],
      ),
    );
  }
}
