import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ce_card.dart';

/// Tarjeta blanca con encabezado propio (numero + icono + titulo),
/// igual al patron "1 Cliente / 2 Monto y Plazo / 3 Interés..." de
/// Nuevo Préstamo. [numero] es opcional (Crear Cliente usa el mismo
/// patron pero sin numerar los pasos).
class CeSectionCard extends StatelessWidget {
  final int? numero;
  final IconData icono;
  final Color colorIcono;
  final String titulo;
  final Widget child;

  const CeSectionCard({
    super.key,
    required this.icono,
    required this.titulo,
    required this.child,
    this.numero,
    this.colorIcono = CEColors.accent,
  });

  @override
  Widget build(BuildContext context) {
    return CeCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (numero != null) ...[
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: CEColors.primary, shape: BoxShape.circle),
                  child: Text(
                    '$numero',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Icon(icono, color: colorIcono, size: 20),
              const SizedBox(width: 8),
              Text(
                titulo,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
