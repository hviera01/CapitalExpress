import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/solicitud_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/widgets/ce_card.dart';
import '../../../../core/widgets/ce_scaffold.dart';
import '../../../../core/widgets/imagen_red_network.dart';
import '../../../../core/widgets/visor_foto_zoom.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../prestamos/data/recibo_prestamo_service.dart';
import '../../../prestamos/providers/prestamos_provider.dart';
import '../../data/aprobar_solicitud.dart';
import '../../providers/solicitudes_provider.dart';

class SolicitudDetalleScreen extends ConsumerStatefulWidget {
  final String solicitudId;

  const SolicitudDetalleScreen({super.key, required this.solicitudId});

  @override
  ConsumerState<SolicitudDetalleScreen> createState() => _SolicitudDetalleScreenState();
}

class _SolicitudDetalleScreenState extends ConsumerState<SolicitudDetalleScreen> {
  bool _procesando = false;

  Future<void> _aceptar(SolicitudModel s) async {
    setState(() => _procesando = true);
    try {
      final usuario = ref.read(authProvider).usuario!;
      final resultado = await aprobarSolicitud(
        prestamoRepo: ref.read(prestamoRepositoryProvider),
        solicitudRepo: ref.read(solicitudRepositoryProvider),
        s: s,
        usuarioUid: usuario.uid,
        usuarioNombre: usuario.nombre,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Préstamo creado: N° ${resultado.numeroPrestamo}')),
      );

      // Se busca el prestamo y se abre la vista previa ANTES de salir
      // de esta pantalla (Navigator.pop() mas abajo) -- usar el context
      // para navegar despues de que su propia pantalla ya se cerro es
      // fragil.
      final prestamo = await ref.read(prestamoRepositoryProvider).obtenerPorId(resultado.prestamoId);
      if (!mounted) return;
      if (prestamo != null) {
        ReciboPrestamoService.mostrarVistaPrevia(context, prestamo);
      }

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesando = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo aprobar: $e')));
    }
  }

  Future<void> _rechazar(SolicitudModel s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rechazar solicitud'),
        content: Text('¿Rechazar la solicitud de ${s.cliente}? No queda ningún registro.'),
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
      await ref.read(solicitudRepositoryProvider).rechazar(s.id,
          usuarioUid: usuario.uid,
          usuarioNombre: usuario.nombre,
          descripcionSolicitud: '${s.cliente} - ${formatearLempiras(s.monto)}');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Solicitud rechazada')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesando = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo rechazar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SolicitudModel?>(
      stream: ref.read(solicitudRepositoryProvider).streamPorId(widget.solicitudId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final s = snapshot.data;
        if (s == null) {
          return const Scaffold(
            body: Center(child: Text('La solicitud ya no existe (fue aprobada o rechazada)')),
          );
        }
        return _contenido(context, s);
      },
    );
  }

  Widget _contenido(BuildContext context, SolicitudModel s) {
    return CeScaffold(
      maxWidth: 720,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Detalle de la Solicitud'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.person_outline, size: 18, color: CEColors.primary),
                    SizedBox(width: 8),
                    Text('CLIENTE', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(s.cliente, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                _fila('Fecha', s.fecha),
                _fila('Lugar', s.lugar),
                _fila('Cobrador solicitante', s.cobradorSolicitante),
                if (s.observaciones.isNotEmpty) _fila('Observaciones', s.observaciones),
              ],
            ),
          ),
          const SizedBox(height: 14),
          CeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.credit_card_outlined, size: 18, color: CEColors.primary),
                    SizedBox(width: 8),
                    Text('RESUMEN FINANCIERO', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),
                _fila('Monto solicitado', formatearLempiras(s.monto)),
                if (s.interesMensual > 0) _fila('Interés mensual', '${s.interesMensual}%'),
                _fila('Interés total', formatearLempiras(s.interesTotal)),
                _fila('Cuotas', '${s.cuotas} (${s.plazo})'),
                _fila('Días efectivos', '${s.diasEfectivos}'),
                if (s.garantia.isNotEmpty) _fila('Garantía', s.garantia),
                const Divider(height: 24),
                _fila('Total a pagar', formatearLempiras(s.totalPagar), negrita: true),
                _fila('Cuota estimada', formatearLempiras(s.cuota), negrita: true),
                if (s.totalPagar <= s.monto)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: CEColors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '⚠️ El total a pagar no supera el monto solicitado — revisar el cálculo de interés.',
                      style: TextStyle(fontSize: 12, color: CEColors.danger),
                    ),
                  ),
              ],
            ),
          ),
          if (s.fotos.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('Evidencia fotográfica', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: s.fotos
                  .map((url) => GestureDetector(
                        onTap: () => abrirFotoZoom(context, url),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(width: 90, height: 90, child: ImagenRedNetwork(url: url)),
                        ),
                      ))
                  .toList(),
            ),
          ],
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
                  onPressed: _procesando ? null : () => _aceptar(s),
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
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _fila(String label, String valor, {bool negrita = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: CEColors.textSecondary, fontSize: 13)),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: negrita ? FontWeight.w800 : FontWeight.w600,
                fontSize: negrita ? 15 : 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
