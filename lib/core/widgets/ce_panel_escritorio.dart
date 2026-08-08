import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Un accion rapida del panel de escritorio (ver CePanelSeccionEscritorio).
class CePanelAccion {
  final IconData icono;
  final String titulo;
  final VoidCallback onTap;

  const CePanelAccion({required this.icono, required this.titulo, required this.onTap});
}

/// Seccion de accesos rapidos para el Panel Admin/Cobrador en
/// escritorio Web -- botones chicos tipo barra de herramientas (icono
/// + texto en una linea) en vez de la grilla de tarjetas grandes tipo
/// "launcher de celular" que se usa en mobile/Windows. Se acomodan
/// solos con Wrap (no una grilla cuadrada de aspect ratio fijo), asi
/// que no queda espacio vacio de mas ni tarjetas gigantes.
class CePanelSeccionEscritorio extends StatelessWidget {
  final String titulo;
  final List<CePanelAccion> acciones;

  const CePanelSeccionEscritorio({super.key, required this.titulo, required this.acciones});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: CEColors.textSecondary,
                letterSpacing: 0.4)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: acciones.map((a) => _BotonAccion(accion: a)).toList(),
        ),
      ],
    );
  }
}

class _BotonAccion extends StatelessWidget {
  final CePanelAccion accion;

  const _BotonAccion({required this.accion});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: accion.onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CEColors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(accion.icono, size: 17, color: CEColors.primary),
              const SizedBox(width: 9),
              Text(accion.titulo,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13, color: CEColors.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}
