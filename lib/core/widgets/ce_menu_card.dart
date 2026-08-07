import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ce_card.dart';

/// Tarjeta de menu para grillas 2 columnas. Variante clara (default) o
/// "hero" oscura (navy) con badge tipo pildora arriba a la derecha, igual
/// que la tarjeta "Solicitudes" del Panel Admin.
class CeMenuCard extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final bool oscuro;
  final String? badge;
  final VoidCallback onTap;

  const CeMenuCard({
    super.key,
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
    this.oscuro = false,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final colorTexto = oscuro ? Colors.white : CEColors.textPrimary;
    final colorSubtexto = oscuro ? Colors.white70 : CEColors.textSecondary;

    return CeCard(
      onTap: onTap,
      color: oscuro ? CEColors.primaryDark : Colors.white,
      borderColor: oscuro ? null : CEColors.border,
      padding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: oscuro ? Colors.white.withValues(alpha: 0.12) : CEColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(icono, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 14),
              Text(
                titulo,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: colorTexto),
              ),
              const SizedBox(height: 4),
              Text(subtitulo, style: TextStyle(fontSize: 12, color: colorSubtexto)),
            ],
          ),
          if (badge != null)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: CEColors.pill,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
