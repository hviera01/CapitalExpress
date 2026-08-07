import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ce_card.dart';

/// Fila de menu de ancho completo: icono circular + titulo/subtitulo +
/// chevron o badge tipo pildora a la derecha.
class CeMenuRow extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final String? badge;
  final bool chevron;
  final IconData? trailingIcon;
  final VoidCallback onTap;

  const CeMenuRow({
    super.key,
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
    this.badge,
    this.chevron = false,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return CeCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: CEColors.iconBadgeBg, shape: BoxShape.circle),
            child: Icon(icono, color: CEColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(subtitulo,
                    style: const TextStyle(fontSize: 12, color: CEColors.textSecondary)),
              ],
            ),
          ),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: CEColors.pill,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge!,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
          if (trailingIcon != null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(trailingIcon, color: CEColors.success),
            )
          else if (chevron)
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.chevron_right, color: CEColors.textSecondary),
            ),
        ],
      ),
    );
  }
}
