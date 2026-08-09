import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/roles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/ce_card.dart';
import '../../../../core/widgets/ce_data_table_style.dart';
import '../../../../core/widgets/ce_scaffold.dart';
import '../../../../core/widgets/ce_web_nav.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../data/ticket_model.dart';
import '../../providers/tickets_provider.dart';
import 'crear_ticket_screen.dart';
import 'ticket_detalle_screen.dart';

/// Lista de tickets: admin ve TODOS (de cualquier usuario), cobrador
/// solo los que el mismo creo (ver ticketsStreamProvider).
class TicketsScreen extends ConsumerWidget {
  const TicketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authProvider).usuario;
    final esAdmin = usuario?.rol == Roles.admin;
    final ticketsAsync = ref.watch(ticketsStreamProvider);

    return CeScaffold(
      maxWidth: 900,
      appBar: AppBar(leading: const BackButton(), title: const Text('Tickets')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => irAPantalla(context, ruta: '/tickets/nuevo', pantalla: const CrearTicketScreen()),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo ticket'),
      ),
      body: ticketsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error al cargar: $e')),
        data: (tickets) {
          if (tickets.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Todavía no hay tickets. Tocá "Nuevo ticket" para reportar un problema '
                    'o pedir algo nuevo.', textAlign: TextAlign.center),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (esEscritorioWeb(context))
                _TablaTickets(tickets: tickets, esAdmin: esAdmin)
              else
                ...tickets.map((t) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _CardTicket(ticket: t),
                    )),
            ],
          );
        },
      ),
    );
  }
}

(IconData, Color) _iconoEstado(String estado) {
  switch (estado) {
    case 'enviado':
      return (Icons.mark_email_unread_outlined, CEColors.warning);
    case 'recibido':
      return (Icons.visibility_outlined, CEColors.accent);
    case 'cerrado':
      return (Icons.check_circle_outline, CEColors.success);
    case 'reabierto':
      return (Icons.replay_circle_filled_outlined, CEColors.danger);
    default:
      return (Icons.help_outline, CEColors.textSecondary);
  }
}

String _etiquetaEstado(String estado) {
  switch (estado) {
    case 'enviado':
      return 'ENVIADO';
    case 'recibido':
      return 'RECIBIDO';
    case 'cerrado':
      return 'CERRADO';
    case 'reabierto':
      return 'REABIERTO';
    default:
      return estado.toUpperCase();
  }
}

class _CardTicket extends ConsumerWidget {
  final TicketModel ticket;

  const _CardTicket({required this.ticket});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (icono, color) = _iconoEstado(ticket.estado);
    final f = DateFormat('dd/MM/yyyy hh:mm a');
    return CeCard(
      onTap: () => irAPantalla(context,
          ruta: '/tickets/${ticket.id}', pantalla: TicketDetalleScreen(ticketId: ticket.id, ticketInicial: ticket)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: ticket.esProblema
                      ? CEColors.danger.withValues(alpha: 0.1)
                      : CEColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(ticket.esProblema ? 'PROBLEMA' : 'NUEVO',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: ticket.esProblema ? CEColors.danger : CEColors.accent)),
              ),
              const Spacer(),
              Icon(icono, size: 14, color: color),
              const SizedBox(width: 4),
              Text(_etiquetaEstado(ticket.estado),
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
          const SizedBox(height: 8),
          Text(ticket.titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 4),
          Text(ticket.descripcion,
              maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.person_outline, size: 12, color: CEColors.textSecondary),
              const SizedBox(width: 3),
              Expanded(
                child: Text(ticket.creadoPorNombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: CEColors.textSecondary)),
              ),
              if (ticket.fechaCreacion != null)
                Text(f.format(ticket.fechaCreacion!),
                    style: const TextStyle(fontSize: 11, color: CEColors.textSecondary)),
            ],
          ),
          if (ticket.precioCotizado != null) ...[
            const SizedBox(height: 6),
            Text('Precio cotizado: ${formatearLempiras(ticket.precioCotizado!)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CEColors.success)),
          ],
        ],
      ),
    );
  }
}

/// Version tabla de la lista de tickets, solo para escritorio Web.
class _TablaTickets extends StatelessWidget {
  final List<TicketModel> tickets;
  final bool esAdmin;

  const _TablaTickets({required this.tickets, required this.esAdmin});

  @override
  Widget build(BuildContext context) {
    final f = DateFormat('dd/MM/yyyy hh:mm a');
    return CeDataTableCard(
      columns: const [
        DataColumn(label: Text('Tipo')),
        DataColumn(label: Text('Título')),
        DataColumn(label: Text('Creado por')),
        DataColumn(label: Text('Fecha')),
        DataColumn(label: Text('Estado')),
      ],
      rows: tickets.map((t) {
        final (icono, color) = _iconoEstado(t.estado);
        return DataRow(
          onSelectChanged: (_) => irAPantalla(context,
              ruta: '/tickets/${t.id}', pantalla: TicketDetalleScreen(ticketId: t.id, ticketInicial: t)),
          cells: [
            DataCell(ceTableBadge(
                t.esProblema ? 'PROBLEMA' : 'NUEVO', t.esProblema ? CEColors.danger : CEColors.accent)),
            DataCell(Text(t.titulo,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis)),
            DataCell(Text(t.creadoPorNombre)),
            DataCell(Text(t.fechaCreacion != null ? f.format(t.fechaCreacion!) : '—')),
            DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icono, size: 15, color: color),
              const SizedBox(width: 5),
              Text(_etiquetaEstado(t.estado),
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
            ])),
          ],
        );
      }).toList(),
    );
  }
}
