import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/roles.dart';
import '../../../../core/models/solicitud_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/ce_card.dart';
import '../../../../core/widgets/ce_data_table_style.dart';
import '../../../../core/widgets/ce_scaffold.dart';
import '../../../../core/widgets/ce_web_nav.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/solicitudes_provider.dart';
import 'solicitud_detalle_screen.dart';

/// Lista de solicitudes pendientes, siempre en vivo: apenas un cobrador
/// manda una solicitud nueva, aparece aca sin recargar.
class SolicitudesScreen extends ConsumerWidget {
  const SolicitudesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authProvider).usuario;
    final esAdmin = Roles.esAdminOEquivalente(usuario?.rol);
    final f = DateFormat('dd/MM/yyyy hh:mm a');

    if (!esAdmin) {
      return CeScaffold(
        appBar: AppBar(leading: const BackButton(), title: const Text('Solicitudes')),
        body: const Center(child: Text('Solo administradores pueden revisar solicitudes')),
      );
    }

    return StreamBuilder<List<SolicitudModel>>(
      stream: ref.read(solicitudRepositoryProvider).streamPendientes(),
      builder: (context, snapshot) {
        final solicitudes = snapshot.data ?? const [];
        return CeScaffold(
          maxWidth: 900,
          appBar: AppBar(
            leading: const BackButton(),
            title: const Text('Solicitudes'),
          ),
          body: snapshot.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('${solicitudes.length} pendientes',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 12),
                    if (solicitudes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(child: Text('No hay solicitudes pendientes')),
                      )
                    else if (esEscritorioWeb(context))
                      _TablaSolicitudes(solicitudes: solicitudes, formatoFecha: f)
                    else
                      ...solicitudes.map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: CeCard(
                              onTap: () => irAPantalla(context,
                                  ruta: '/solicitudes/${s.id}',
                                  pantalla: SolicitudDetalleScreen(solicitudId: s.id)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(s.cliente,
                                            style: const TextStyle(fontWeight: FontWeight.w700)),
                                      ),
                                      Text(formatearLempiras(s.monto),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w800, color: CEColors.accent)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text('${s.cuotas} cuotas · ${s.plazo}',
                                      style: const TextStyle(fontSize: 12, color: CEColors.textSecondary)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.person_outline,
                                          size: 13, color: CEColors.textSecondary),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          s.cobradorSolicitante,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 12, color: CEColors.textSecondary),
                                        ),
                                      ),
                                      if (s.fechaCreacion != null)
                                        Text(f.format(s.fechaCreacion!.toDate()),
                                            style: const TextStyle(
                                                fontSize: 11, color: CEColors.textSecondary)),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () => irAPantalla(context,
                              ruta: '/solicitudes/${s.id}',
                              pantalla: SolicitudDetalleScreen(solicitudId: s.id)),
                                          child: const Text('Ver detalle'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          )),
                  ],
                ),
        );
      },
    );
  }
}

/// Version tabla de Solicitudes, solo para escritorio Web (ver
/// esEscritorioWeb).
class _TablaSolicitudes extends StatelessWidget {
  final List<SolicitudModel> solicitudes;
  final DateFormat formatoFecha;

  const _TablaSolicitudes({required this.solicitudes, required this.formatoFecha});

  @override
  Widget build(BuildContext context) {
    return CeDataTableCard(
      columns: const [
        DataColumn(label: Text('Cliente')),
        DataColumn(label: Text('Monto'), numeric: true),
        DataColumn(label: Text('Cuotas')),
        DataColumn(label: Text('Cobrador solicitante')),
        DataColumn(label: Text('Fecha')),
        DataColumn(label: Text('Acciones')),
      ],
      rows: solicitudes.map((s) {
            return DataRow(
              onSelectChanged: (_) => irAPantalla(context,
                  ruta: '/solicitudes/${s.id}',
                  pantalla: SolicitudDetalleScreen(solicitudId: s.id)),
              cells: [
                DataCell(Text(s.cliente, style: const TextStyle(fontWeight: FontWeight.w600))),
                DataCell(Text(formatearLempiras(s.monto),
                    style: const TextStyle(fontWeight: FontWeight.w700, color: CEColors.accent))),
                DataCell(Text('${s.cuotas} · ${s.plazo}')),
                DataCell(Text(s.cobradorSolicitante)),
                DataCell(Text(
                    s.fechaCreacion != null ? formatoFecha.format(s.fechaCreacion!.toDate()) : '—')),
                DataCell(TextButton(
                  onPressed: () => irAPantalla(context,
                              ruta: '/solicitudes/${s.id}',
                              pantalla: SolicitudDetalleScreen(solicitudId: s.id)),
                  child: const Text('Ver detalle'),
                )),
              ],
            );
          }).toList(),
    );
  }
}
