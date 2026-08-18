import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/etiquetas_edicion.dart';
import '../../../../core/models/solicitud_edicion_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ce_card.dart';
import '../../../../core/widgets/ce_scaffold.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/solicitud_edicion_provider.dart';

class SolicitudEdicionDetalleScreen extends ConsumerStatefulWidget {
  final String solicitudId;

  const SolicitudEdicionDetalleScreen({super.key, required this.solicitudId});

  @override
  ConsumerState<SolicitudEdicionDetalleScreen> createState() =>
      _SolicitudEdicionDetalleScreenState();
}

class _SolicitudEdicionDetalleScreenState extends ConsumerState<SolicitudEdicionDetalleScreen> {
  bool _procesando = false;

  Map<String, String> _etiquetas(String entidadTipo) =>
      entidadTipo == 'cliente' ? etiquetasCampoCliente : etiquetasCampoPrestamo;

  Future<void> _aprobar(SolicitudEdicionModel s) async {
    setState(() => _procesando = true);
    try {
      final usuario = ref.read(authProvider).usuario!;
      await ref.read(solicitudEdicionRepositoryProvider).aprobar(
            s.id,
            usuarioUid: usuario.uid,
            usuarioNombre: usuario.nombre,
            descripcion: '${s.entidadTipo == 'cliente' ? 'Cliente' : 'Préstamo'}: ${s.entidadNombre}',
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Solicitud aprobada — el cobrador tiene 1 hora para aplicar el cambio')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo aprobar: $e')));
    }
  }

  Future<void> _rechazar(SolicitudEdicionModel s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rechazar solicitud'),
        content: Text('¿Rechazar la solicitud de edición de ${s.entidadNombre}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rechazar', style: TextStyle(color: CEColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _procesando = true);
    try {
      final usuario = ref.read(authProvider).usuario!;
      await ref.read(solicitudEdicionRepositoryProvider).rechazar(
            s.id,
            usuarioUid: usuario.uid,
            usuarioNombre: usuario.nombre,
            descripcion: '${s.entidadTipo == 'cliente' ? 'Cliente' : 'Préstamo'}: ${s.entidadNombre}',
          );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Solicitud rechazada')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo rechazar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SolicitudEdicionModel?>(
      stream: ref.read(solicitudEdicionRepositoryProvider).streamPorId(widget.solicitudId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final s = snapshot.data;
        if (s == null) {
          return const Scaffold(body: Center(child: Text('La solicitud ya no existe')));
        }
        return _contenido(context, s);
      },
    );
  }

  Widget _contenido(BuildContext context, SolicitudEdicionModel s) {
    final etiquetas = _etiquetas(s.entidadTipo);
    final pendiente = s.estado == 'pendiente';
    return CeScaffold(
      maxWidth: 720,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Solicitud de Edición'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(s.entidadTipo == 'cliente' ? Icons.person_outline : Icons.credit_card_outlined,
                        size: 18, color: CEColors.primary),
                    const SizedBox(width: 8),
                    Text(s.entidadTipo == 'cliente' ? 'CLIENTE' : 'PRÉSTAMO',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(s.entidadNombre,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                const SizedBox(height: 4),
                Text('Solicitado por ${s.solicitanteNombre}',
                    style: const TextStyle(fontSize: 12, color: CEColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          CeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CAMBIOS PROPUESTOS',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                const SizedBox(height: 12),
                for (final campo in s.valoresNuevos.keys)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(etiquetas[campo] ?? campo,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: Text('${s.valoresAnteriores[campo] ?? '—'}',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: CEColors.textSecondary,
                                      decoration: TextDecoration.lineThrough)),
                            ),
                            const Icon(Icons.arrow_forward, size: 14, color: CEColors.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('${s.valoresNuevos[campo]}',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: CEColors.success)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (!pendiente) ...[
            const SizedBox(height: 14),
            CeCard(
              child: Text('Estado actual: ${s.estado.toUpperCase()}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
          if (pendiente) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _procesando ? null : () => _rechazar(s),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CEColors.danger,
                      side: const BorderSide(color: CEColors.danger),
                    ),
                    icon: const Icon(Icons.close),
                    label: const Text('Rechazar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _procesando ? null : () => _aprobar(s),
                    icon: _procesando
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Aprobar'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
