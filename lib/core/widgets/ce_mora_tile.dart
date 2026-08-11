import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/prestamo_model.dart';
import '../theme/app_theme.dart';
import '../utils/currency_utils.dart';

/// Una fila de mora individual (monto, cuando se aplico, quien la
/// aplico, y si esta cancelada, cuando y por quien) -- reusada en
/// Detalle del Prestamo y Ver Cuotas para no duplicar el mismo diseño
/// en los dos lados. `onCancelar` null = no se muestra el boton (ej.
/// mora ya cancelada, o quien mira no es admin).
class CeMoraTile extends StatelessWidget {
  final MoraIndividual mora;
  final VoidCallback? onCancelar;

  const CeMoraTile({super.key, required this.mora, this.onCancelar});

  @override
  Widget build(BuildContext context) {
    final formatoFecha = DateFormat('dd/MM/yyyy');
    final activa = !mora.cancelada;
    final color = activa ? CEColors.danger : CEColors.textSecondary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(formatearLempiras(mora.monto),
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: color,
                          decoration: activa ? null : TextDecoration.lineThrough)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(activa ? 'ACTIVA' : 'CANCELADA',
                        style:
                            TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Aplicada el ${mora.fechaAplicada != null ? formatoFecha.format(mora.fechaAplicada!.toDate()) : '—'}'
                '${mora.aplicadaPor.isNotEmpty ? ' por ${mora.aplicadaPor}' : ''}',
                style: const TextStyle(fontSize: 12, color: CEColors.textSecondary),
              ),
              if (mora.cancelada)
                Text(
                  'Cancelada el ${mora.fechaCancelada != null ? formatoFecha.format(mora.fechaCancelada!.toDate()) : '—'}'
                  '${mora.canceladaPor.isNotEmpty ? ' por ${mora.canceladaPor}' : ''}',
                  style: const TextStyle(fontSize: 12, color: CEColors.textSecondary),
                ),
            ],
          ),
        ),
        if (onCancelar != null)
          TextButton(
            onPressed: onCancelar,
            style: TextButton.styleFrom(foregroundColor: CEColors.danger),
            child: const Text('Cancelar'),
          ),
      ],
    );
  }
}
