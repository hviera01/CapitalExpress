import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/roles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/uppercase_text_formatter.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/widgets/ce_card.dart';
import '../../../../core/widgets/ce_scaffold.dart';
import '../../../../core/widgets/imagen_red_network.dart';
import '../../../../core/widgets/visor_foto_zoom.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../data/ticket_model.dart';
import '../../providers/tickets_provider.dart';

class TicketDetalleScreen extends ConsumerStatefulWidget {
  final String ticketId;
  final TicketModel? ticketInicial;

  const TicketDetalleScreen({super.key, required this.ticketId, this.ticketInicial});

  @override
  ConsumerState<TicketDetalleScreen> createState() => _TicketDetalleScreenState();
}

class _TicketDetalleScreenState extends ConsumerState<TicketDetalleScreen> {
  late final Stream<TicketModel?> _stream =
      ref.read(ticketRepositoryProvider).streamPorId(widget.ticketId);

  bool _procesando = false;
  final _respuestaCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();

  @override
  void dispose() {
    _respuestaCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  Future<void> _marcarRecibido() async {
    setState(() => _procesando = true);
    try {
      await ref.read(ticketRepositoryProvider).marcarRecibido(widget.ticketId);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _responderYCerrar(TicketModel t) async {
    if (_respuestaCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Escribí una respuesta')));
      return;
    }
    double? precio;
    if (!t.esProblema) {
      precio = double.tryParse(_precioCtrl.text.replaceAll(',', '.'));
      if (precio == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Ingresá el precio que vas a cobrar')));
        return;
      }
    }
    setState(() => _procesando = true);
    try {
      final usuario = ref.read(authProvider).usuario!;
      await ref.read(ticketRepositoryProvider).responderYCerrar(
            widget.ticketId,
            respuesta: _respuestaCtrl.text.trim(),
            precioCotizado: precio,
            respondidoPor: usuario.nombre,
          );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Respuesta enviada, ticket cerrado')));
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  Future<void> _reabrir() async {
    setState(() => _procesando = true);
    try {
      await ref.read(ticketRepositoryProvider).reabrir(widget.ticketId);
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<TicketModel?>(
      stream: _stream,
      initialData: widget.ticketInicial,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final t = snap.data;
        if (t == null) {
          return const Scaffold(body: Center(child: Text('Ticket no encontrado')));
        }
        return _contenido(context, t);
      },
    );
  }

  Widget _contenido(BuildContext context, TicketModel t) {
    final usuario = ref.watch(authProvider).usuario;
    final esAdmin = Roles.esAdminOEquivalente(usuario?.rol);
    final esCreador = usuario?.uid == t.creadoPorUid;
    final f = DateFormat('dd/MM/yyyy hh:mm a');

    return CeScaffold(
      maxWidth: 720,
      appBar: AppBar(leading: const BackButton(), title: const Text('Detalle del Ticket')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: t.esProblema
                      ? CEColors.danger.withValues(alpha: 0.1)
                      : CEColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(t.esProblema ? 'PROBLEMA' : 'ALGO NUEVO',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: t.esProblema ? CEColors.danger : CEColors.accent)),
              ),
              const Spacer(),
              _badgeEstado(t.estado),
            ],
          ),
          const SizedBox(height: 14),
          Text(t.titulo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 6),
          Text('${t.creadoPorNombre} (${t.creadoPorRol}) · '
              '${t.fechaCreacion != null ? f.format(t.fechaCreacion!) : ''}',
              style: const TextStyle(fontSize: 12, color: CEColors.textSecondary)),
          const SizedBox(height: 14),
          CeCard(child: Text(t.descripcion, style: const TextStyle(fontSize: 13.5))),
          if (t.fotos.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: t.fotos
                  .map((url) => GestureDetector(
                        onTap: () => abrirFotoZoom(context, url),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                              width: 84, height: 84, child: ImagenRedNetwork(url: url)),
                        ),
                      ))
                  .toList(),
            ),
          ],
          if (t.tieneRespuesta) ...[
            const SizedBox(height: 20),
            const Text('RESPUESTA',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: CEColors.textSecondary,
                    letterSpacing: 0.4)),
            const SizedBox(height: 8),
            CeCard(
              color: CEColors.primary.withValues(alpha: 0.04),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.respuesta, style: const TextStyle(fontSize: 13.5)),
                  if (t.precioCotizado != null) ...[
                    const SizedBox(height: 10),
                    Text('Precio cotizado: ${formatearLempiras(t.precioCotizado!)}',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800, color: CEColors.success)),
                  ],
                  const SizedBox(height: 8),
                  Text(
                      '${t.respondidoPor} · '
                      '${t.fechaRespuesta != null ? f.format(t.fechaRespuesta!) : ''}',
                      style: const TextStyle(fontSize: 11, color: CEColors.textSecondary)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (esAdmin && t.estado == 'enviado')
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _procesando ? null : _marcarRecibido,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Marcar como recibido'),
              ),
            ),
          if (esAdmin && (t.estado == 'recibido' || t.estado == 'reabierto')) ...[
            const Text('Responder',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 10),
            TextField(
              controller: _respuestaCtrl,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: t.esProblema ? 'Ej: ya está solucionado, actualizá la app' : 'Detalle de tu respuesta',
              ),
              inputFormatters: const [upperCaseTextFormatter],
              textCapitalization: TextCapitalization.characters,
            ),
            if (!t.esProblema) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _precioCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Precio a cobrar (L.) *'),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _procesando ? null : () => _responderYCerrar(t),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Responder y cerrar'),
              ),
            ),
          ],
          if (t.estado == 'cerrado' && (esAdmin || esCreador))
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _procesando ? null : _reabrir,
                icon: const Icon(Icons.replay_outlined),
                label: const Text('Reabrir'),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _badgeEstado(String estado) {
    final (icono, color, texto) = switch (estado) {
      'enviado' => (Icons.mark_email_unread_outlined, CEColors.warning, 'ENVIADO'),
      'recibido' => (Icons.visibility_outlined, CEColors.accent, 'RECIBIDO'),
      'cerrado' => (Icons.check_circle_outline, CEColors.success, 'CERRADO'),
      'reabierto' => (Icons.replay_circle_filled_outlined, CEColors.danger, 'REABIERTO'),
      _ => (Icons.help_outline, CEColors.textSecondary, estado.toUpperCase()),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 15, color: color),
        const SizedBox(width: 5),
        Text(texto, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}
