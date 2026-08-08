import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/pago_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/widgets/ce_card.dart';
import '../../../../core/widgets/ce_data_table_style.dart';
import '../../data/recibo_pago_service.dart';
import '../../providers/pagos_provider.dart';

/// Fila de un pago con Reimprimir/Eliminar, reusada en Reporte de
/// Cobros y en el Historial de Pagos por Préstamo para que ambos
/// lugares tengan exactamente las mismas acciones.
class PagoTile extends ConsumerWidget {
  final PagoModel pago;
  final VoidCallback onEliminado;
  final bool mostrarPrestamo;
  final bool puedeEliminar;

  const PagoTile({
    super.key,
    required this.pago,
    required this.onEliminado,
    this.mostrarPrestamo = true,
    this.puedeEliminar = true,
  });

  Future<void> _eliminar(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar pago'),
        content: Text(
          '¿Eliminar este abono de ${formatearLempiras(pago.total)}? '
          'El saldo del préstamo se va a recalcular sin este pago. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: CEColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(pagoRepositoryProvider).eliminarConReversion(pago);
      onEliminado();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Pago eliminado')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = DateFormat('dd/MM/yyyy hh:mm a');

    return CeCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pago.clienteNombre.isEmpty ? 'Cliente' : pago.clienteNombre,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  mostrarPrestamo
                      ? 'N° ${pago.numeroPrestamo} · ${pago.nombreCobrador}'
                      : pago.nombreCobrador,
                  style: const TextStyle(fontSize: 11, color: CEColors.textSecondary),
                ),
                if (pago.descripcionCuotas.isNotEmpty)
                  Text(pago.descripcionCuotas,
                      style: const TextStyle(fontSize: 11, color: CEColors.textSecondary)),
                if (pago.fechaPago != null)
                  Text(f.format(pago.fechaPago!.toDate()),
                      style: const TextStyle(fontSize: 11, color: CEColors.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatearLempiras(pago.total),
                  style: const TextStyle(fontWeight: FontWeight.w800, color: CEColors.accent)),
              if (pago.mora > 0)
                Text('incl. ${formatearLempiras(pago.mora)} mora',
                    style: const TextStyle(fontSize: 10, color: CEColors.danger)),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: CEColors.textSecondary),
            onSelected: (accion) {
              if (accion == 'reimprimir') {
                ReciboPagoService.mostrarVistaPrevia(context, pago);
              } else if (accion == 'eliminar') {
                _eliminar(context, ref);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'reimprimir',
                child: ListTile(
                  leading: Icon(Icons.print_outlined),
                  title: Text('Reimprimir'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (puedeEliminar)
                const PopupMenuItem(
                  value: 'eliminar',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline, color: CEColors.danger),
                    title: Text('Eliminar'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Version tabla de una lista de pagos, solo para escritorio Web (ver
/// esEscritorioWeb) -- mismas acciones (Reimprimir/Eliminar) que
/// PagoTile, reusada en Reporte de Cobros e Historial de Pagos por
/// Préstamo.
class TablaPagos extends ConsumerWidget {
  final List<PagoModel> pagos;
  final bool mostrarPrestamo;
  final bool puedeEliminar;
  final ValueChanged<PagoModel> onEliminado;

  const TablaPagos({
    super.key,
    required this.pagos,
    required this.onEliminado,
    this.mostrarPrestamo = true,
    this.puedeEliminar = true,
  });

  Future<void> _eliminar(BuildContext context, WidgetRef ref, PagoModel pago) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar pago'),
        content: Text(
          '¿Eliminar este abono de ${formatearLempiras(pago.total)}? '
          'El saldo del préstamo se va a recalcular sin este pago. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: CEColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(pagoRepositoryProvider).eliminarConReversion(pago);
      onEliminado(pago);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pago eliminado')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = DateFormat('dd/MM/yyyy hh:mm a');
    return CeDataTableCard(
      columns: [
        const DataColumn(label: Text('Cliente')),
        if (mostrarPrestamo) const DataColumn(label: Text('N°')),
        const DataColumn(label: Text('Cobrador')),
        const DataColumn(label: Text('Fecha')),
        const DataColumn(label: Text('Abono'), numeric: true),
        const DataColumn(label: Text('Mora'), numeric: true),
        const DataColumn(label: Text('')),
      ],
      rows: pagos.map((p) {
            return DataRow(cells: [
              DataCell(Text(p.clienteNombre.isEmpty ? 'Cliente' : p.clienteNombre,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
              if (mostrarPrestamo) DataCell(Text('#${p.numeroPrestamo}')),
              DataCell(Text(p.nombreCobrador.isEmpty ? 'N/D' : p.nombreCobrador)),
              DataCell(Text(p.fechaPago != null ? f.format(p.fechaPago!.toDate()) : '—')),
              DataCell(Text(formatearLempiras(p.total),
                  style: const TextStyle(fontWeight: FontWeight.w700, color: CEColors.accent))),
              DataCell(Text(
                p.mora > 0 ? formatearLempiras(p.mora) : '—',
                style: TextStyle(color: p.mora > 0 ? CEColors.danger : null),
              )),
              DataCell(PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18, color: CEColors.textSecondary),
                onSelected: (accion) {
                  if (accion == 'reimprimir') {
                    ReciboPagoService.mostrarVistaPrevia(context, p);
                  } else if (accion == 'eliminar') {
                    _eliminar(context, ref, p);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'reimprimir',
                    child: ListTile(
                      leading: Icon(Icons.print_outlined),
                      title: Text('Reimprimir'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  if (puedeEliminar)
                    const PopupMenuItem(
                      value: 'eliminar',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline, color: CEColors.danger),
                        title: Text('Eliminar'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                ],
              )),
            ]);
          }).toList(),
    );
  }
}
