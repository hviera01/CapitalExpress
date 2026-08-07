import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Filtro de fecha reusado en todos los reportes con rango: chips
/// rapidos (Hoy/Semana/Mes/Todos) + botones de Fecha Inicio/Fecha Fin
/// para un rango a medida. Ambos escriben el mismo par de fechas, asi
/// que se pueden combinar (elegir un chip y despues ajustar a mano).
class FiltroFechaRango extends StatelessWidget {
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final void Function(DateTime? inicio, DateTime? fin) onCambio;

  const FiltroFechaRango({
    super.key,
    required this.fechaInicio,
    required this.fechaFin,
    required this.onCambio,
  });

  Future<void> _elegirFecha(BuildContext context, {required bool esInicio}) async {
    final f = await showDatePicker(
      context: context,
      initialDate: (esInicio ? fechaInicio : fechaFin) ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now(),
    );
    if (f == null) return;
    if (esInicio) {
      onCambio(f, fechaFin);
    } else {
      onCambio(fechaInicio, f);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = DateFormat('dd/MM/yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Hoy'),
              onPressed: () {
                final hoy = DateTime.now();
                onCambio(DateTime(hoy.year, hoy.month, hoy.day), hoy);
              },
            ),
            ActionChip(
              label: const Text('Semana'),
              onPressed: () {
                final hoy = DateTime.now();
                onCambio(hoy.subtract(const Duration(days: 7)), hoy);
              },
            ),
            ActionChip(
              label: const Text('Mes'),
              onPressed: () {
                final hoy = DateTime.now();
                onCambio(DateTime(hoy.year, hoy.month, 1), hoy);
              },
            ),
            ActionChip(
              label: const Text('Todos'),
              onPressed: () => onCambio(null, null),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _elegirFecha(context, esInicio: true),
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text(fechaInicio == null ? 'Fecha Inicio' : f.format(fechaInicio!)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _elegirFecha(context, esInicio: false),
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text(fechaFin == null ? 'Fecha Fin' : f.format(fechaFin!)),
              ),
            ),
            if (fechaInicio != null || fechaFin != null)
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Limpiar fechas',
                onPressed: () => onCambio(null, null),
              ),
          ],
        ),
      ],
    );
  }
}
