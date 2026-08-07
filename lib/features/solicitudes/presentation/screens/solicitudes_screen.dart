import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/roles.dart';
import '../../../../core/models/solicitud_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/widgets/ce_card.dart';
import '../../../../core/widgets/ce_scaffold.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/solicitudes_provider.dart';

/// Lista de solicitudes pendientes, siempre en vivo: apenas un cobrador
/// manda una solicitud nueva, aparece aca sin recargar.
class SolicitudesScreen extends ConsumerWidget {
  const SolicitudesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authProvider).usuario;
    final esAdmin = usuario?.rol == Roles.admin;
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
                    else
                      ...solicitudes.map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: CeCard(
                              onTap: () => context.push('/solicitudes/${s.id}'),
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
                                          onPressed: () => context.push('/solicitudes/${s.id}'),
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
