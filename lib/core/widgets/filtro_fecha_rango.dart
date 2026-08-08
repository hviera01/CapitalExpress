import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Filtro de fecha reusado en todos los reportes con rango: chips
/// rapidos (Hoy/Semana/Mes/Todos) + botones de Fecha Inicio/Fecha Fin
/// para un rango a medida.
///
/// Los botones de Fecha Inicio/Fecha Fin NO disparan `onCambio` al
/// tocar cada uno -- solo actualizan la seleccion local. Asi se puede
/// elegir primero la fecha de inicio y despues la de fin sin que la
/// pantalla recargue (y pierda el foco/scroll) a mitad de camino;
/// `onCambio` se dispara recien al tocar "Buscar". Los chips rapidos
/// (que ya traen el rango completo en un solo toque) siguen aplicando
/// al instante.
class FiltroFechaRango extends StatefulWidget {
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final void Function(DateTime? inicio, DateTime? fin) onCambio;

  const FiltroFechaRango({
    super.key,
    required this.fechaInicio,
    required this.fechaFin,
    required this.onCambio,
  });

  @override
  State<FiltroFechaRango> createState() => _FiltroFechaRangoState();
}

class _FiltroFechaRangoState extends State<FiltroFechaRango> {
  DateTime? _inicioPendiente;
  DateTime? _finPendiente;

  @override
  void initState() {
    super.initState();
    _inicioPendiente = widget.fechaInicio;
    _finPendiente = widget.fechaFin;
  }

  @override
  void didUpdateWidget(FiltroFechaRango oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si el padre cambio las fechas por su cuenta (ej. un chip rapido,
    // o "Limpiar fechas"), se refleja aca tambien.
    if (widget.fechaInicio != oldWidget.fechaInicio || widget.fechaFin != oldWidget.fechaFin) {
      _inicioPendiente = widget.fechaInicio;
      _finPendiente = widget.fechaFin;
    }
  }

  bool get _hayCambiosSinAplicar =>
      _inicioPendiente != widget.fechaInicio || _finPendiente != widget.fechaFin;

  Future<void> _elegirFecha({required bool esInicio}) async {
    final f = await showDatePicker(
      context: context,
      initialDate: (esInicio ? _inicioPendiente : _finPendiente) ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now(),
    );
    if (f == null) return;
    setState(() {
      if (esInicio) {
        _inicioPendiente = f;
      } else {
        _finPendiente = f;
      }
    });
  }

  void _aplicarRapido(DateTime? inicio, DateTime? fin) {
    setState(() {
      _inicioPendiente = inicio;
      _finPendiente = fin;
    });
    widget.onCambio(inicio, fin);
  }

  @override
  Widget build(BuildContext context) {
    final f = DateFormat('dd/MM/yyyy', 'es');

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
                _aplicarRapido(DateTime(hoy.year, hoy.month, hoy.day), hoy);
              },
            ),
            ActionChip(
              label: const Text('Semana'),
              onPressed: () {
                final hoy = DateTime.now();
                _aplicarRapido(hoy.subtract(const Duration(days: 7)), hoy);
              },
            ),
            ActionChip(
              label: const Text('Mes'),
              onPressed: () {
                final hoy = DateTime.now();
                _aplicarRapido(DateTime(hoy.year, hoy.month, 1), hoy);
              },
            ),
            ActionChip(
              label: const Text('Todos'),
              onPressed: () => _aplicarRapido(null, null),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _elegirFecha(esInicio: true),
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text(_inicioPendiente == null ? 'Fecha Inicio' : f.format(_inicioPendiente!)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _elegirFecha(esInicio: false),
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text(_finPendiente == null ? 'Fecha Fin' : f.format(_finPendiente!)),
              ),
            ),
            if (_inicioPendiente != null || _finPendiente != null)
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Limpiar fechas',
                onPressed: () => _aplicarRapido(null, null),
              ),
          ],
        ),
        if (_hayCambiosSinAplicar) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => widget.onCambio(_inicioPendiente, _finPendiente),
              icon: const Icon(Icons.search, size: 18),
              label: const Text('Buscar con estas fechas'),
            ),
          ),
        ],
      ],
    );
  }
}
