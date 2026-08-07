import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/pago_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/widgets/ce_card.dart';
import '../../data/recibo_pago_service.dart';
import '../../providers/pagos_provider.dart';

/// Fila de un pago con Reimprimir/Eliminar, reusada en Reporte de
/// Cobros y en el Historial de Pagos por Préstamo para que ambos
/// lugares tengan exactamente las mismas acciones.
class PagoTile extends ConsumerWidget {
  final PagoModel pago;
  final VoidCallback onEliminado;
  final bool mostrarPrestamo;

  const PagoTile({
    super.key,
    required this.pago,
    required this.onEliminado,
    this.mostrarPrestamo = true,
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
                ReciboPagoService.imprimir(pago);
              } else if (accion == 'eliminar') {
                _eliminar(context, ref);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'reimprimir',
                child: ListTile(
                  leading: Icon(Icons.print_outlined),
                  title: Text('Reimprimir'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
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
