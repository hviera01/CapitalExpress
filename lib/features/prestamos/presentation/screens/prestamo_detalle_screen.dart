import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/roles.dart';
import '../../../../core/models/prestamo_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/widgets/ce_card.dart';
import '../../../../core/widgets/ce_mora_tile.dart';
import '../../../../core/widgets/ce_scaffold.dart';
import '../../../../core/widgets/ce_web_nav.dart';
import '../../../../core/widgets/imagen_red_network.dart';
import '../../../../core/widgets/visor_foto_zoom.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../pagos/presentation/screens/cobrar_screen.dart';
import '../../../pagos/presentation/screens/historial_pagos_prestamo_screen.dart';
import '../../../pagos/presentation/screens/ver_cuotas_screen.dart';
import '../../data/recibo_prestamo_service.dart';
import '../../providers/prestamos_provider.dart';
import 'editar_prestamo_screen.dart';

class PrestamoDetalleScreen extends ConsumerStatefulWidget {
  final String prestamoId;
  final PrestamoModel? prestamoInicial;

  const PrestamoDetalleScreen({super.key, required this.prestamoId, this.prestamoInicial});

  @override
  ConsumerState<PrestamoDetalleScreen> createState() => _PrestamoDetalleScreenState();
}

class _PrestamoDetalleScreenState extends ConsumerState<PrestamoDetalleScreen> {
  // Stream en vivo: si se aplica una mora, se registra/borra un pago, o
  // se edita el prestamo desde otra pantalla/dispositivo, esto se
  // actualiza solo -- no hace falta volver a entrar ni tocar "refrescar".
  late final Stream<PrestamoModel?> _stream =
      ref.read(prestamoRepositoryProvider).streamPorId(widget.prestamoId);

  Future<void> _eliminar(PrestamoModel p) async {
    final usuario = ref.read(authProvider).usuario!;
    await ref.read(prestamoRepositoryProvider).marcarEliminado(
          widget.prestamoId,
          eliminadoPor: usuario.nombre,
          usuarioUid: usuario.uid,
          descripcionPrestamo: 'N° ${p.numeroPrestamo} - ${p.cliente}',
        );
  }

  Future<void> _restaurar(PrestamoModel p) async {
    final usuario = ref.read(authProvider).usuario!;
    await ref.read(prestamoRepositoryProvider).restaurar(
          widget.prestamoId,
          usuarioUid: usuario.uid,
          usuarioNombre: usuario.nombre,
          descripcionPrestamo: 'N° ${p.numeroPrestamo} - ${p.cliente}',
        );
  }

  void _reimprimir(BuildContext context, PrestamoModel p) {
    ReciboPrestamoService.mostrarVistaPrevia(context, p);
  }

  Future<void> _cancelarMora(BuildContext context, double moraActual) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar mora'),
        content: Text(
          'Se eliminará la mora de ${formatearLempiras(moraActual)} del saldo pendiente. '
          'El saldo volverá a su valor sin mora. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Volver')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar mora', style: TextStyle(color: CEColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(prestamoRepositoryProvider).cancelarMora(widget.prestamoId);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Mora cancelada')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo cancelar la mora: $e')));
      }
    }
  }

  Future<void> _cancelarMoraIndividual(
      BuildContext context, PrestamoModel p, MoraIndividual mora) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar esta mora'),
        content: Text(
          'Se quitará esta mora de ${formatearLempiras(mora.monto)} (aplicada el '
          '${mora.fechaAplicada != null ? DateFormat('dd/MM/yyyy').format(mora.fechaAplicada!.toDate()) : '—'}) '
          'del saldo pendiente. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Volver')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar mora', style: TextStyle(color: CEColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final usuario = ref.read(authProvider).usuario!;
      await ref.read(prestamoRepositoryProvider).cancelarMoraIndividual(
            widget.prestamoId,
            mora.id,
            usuarioUid: usuario.uid,
            usuarioNombre: usuario.nombre,
            descripcionPrestamo: 'N° ${p.numeroPrestamo} - ${p.cliente}',
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Mora cancelada')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo cancelar: $e')));
      }
    }
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'saldado':
        return CEColors.success;
      case 'mora':
        return CEColors.danger;
      default:
        return CEColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PrestamoModel?>(
      stream: _stream,
      initialData: widget.prestamoInicial,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error al cargar el préstamo: ${snapshot.error}')),
          );
        }
        final p = snapshot.data;
        if (p == null) {
          return const Scaffold(body: Center(child: Text('Préstamo no encontrado')));
        }
        return _contenido(context, p);
      },
    );
  }

  Widget _contenido(BuildContext context, PrestamoModel p) {
    final usuario = ref.watch(authProvider).usuario;
    final esAdmin = Roles.esAdminOEquivalente(usuario?.rol);
    final formatoFecha = DateFormat('dd/MM/yyyy');
    final colorEstado = _colorEstado(p.estado);

    return CeScaffold(
      maxWidth: 720,
      appBar: AppBar(
        // Pop con el ultimo PrestamoModel conocido (viene del stream en
        // vivo de arriba) en vez de un BackButton comun -- asi quien
        // llamo (Ver Prestamos) puede actualizar esa fila directo, sin
        // tener que pedirle el documento a Firestore otra vez apenas
        // se vuelve. Ese pedido + el setState/rebuild que dispara
        // llegaban justo encima de la animacion de salida y se sentia
        // pesado al dar "atras".
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(p),
        ),
        title: const Text('Detalle del Préstamo'),
        actions: [
          if (!p.eliminado)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar',
              onPressed: () => irAPantalla(context,
                  ruta: '/prestamos/${p.prestamoId}/editar',
                  extra: p,
                  pantalla: EditarPrestamoScreen(prestamoId: p.prestamoId, prestamoInicial: p)),
            ),
          if (esAdmin)
            IconButton(
              icon: Icon(p.eliminado ? Icons.restore_from_trash_outlined : Icons.delete_outline),
              tooltip: p.eliminado ? 'Restaurar' : 'Eliminar',
              onPressed: p.eliminado ? () => _restaurar(p) : () => _eliminar(p),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (p.eliminado)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CEColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('Eliminado por ${p.eliminadoPor ?? ''}',
                  style: const TextStyle(color: CEColors.danger, fontWeight: FontWeight.w600)),
            ),
          // Hero: numero de prestamo
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: CEColors.accent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: 0,
                  top: 0,
                  child: Icon(Icons.tag, color: Colors.white.withValues(alpha: 0.35), size: 40),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NÚMERO DE PRÉSTAMO',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      p.numeroPrestamo,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          CeCard(
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ESTADO DEL PRÉSTAMO',
                        style: TextStyle(fontSize: 11, color: CEColors.textSecondary)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(color: colorEstado, shape: BoxShape.circle),
                        ),
                        Text(
                          p.estado.toUpperCase(),
                          style: TextStyle(
                              color: colorEstado, fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                Icon(Icons.check_circle_outline, color: colorEstado),
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
                    Icon(Icons.person_outline, size: 18, color: CEColors.primary),
                    SizedBox(width: 8),
                    Text('INFORMACIÓN DEL CLIENTE',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Nombre', style: TextStyle(fontSize: 12, color: CEColors.textSecondary)),
                const SizedBox(height: 4),
                Text(p.cliente.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
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
                    Text('INFORMACIÓN FINANCIERA',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 14),
                _filaFinanciera('Monto prestado', formatearLempiras(p.monto)),
                if (p.usarInteresMensual)
                  _filaFinanciera('Interés mensual', '${p.interesMensual}%'),
                _filaFinanciera('Interés total', formatearLempiras(p.interes)),
                _filaFinanciera('Total a pagar', formatearLempiras(p.totalPagar)),
                _filaFinanciera('Monto pagado', formatearLempiras(p.montoPagado),
                    color: CEColors.success),
                const Divider(height: 24),
                _filaFinanciera('Saldo pendiente', formatearLempiras(p.saldo),
                    color: CEColors.danger, negrita: true),
                if (p.mora > 0)
                  _filaFinanciera('Mora acumulada', formatearLempiras(p.mora),
                      color: CEColors.danger),
                if (esAdmin && p.estado == 'mora') ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: CEColors.danger,
                        side: const BorderSide(color: CEColors.danger),
                      ),
                      onPressed: () => _cancelarMora(context, p.mora),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancelar Mora'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (p.morasIndividuales.isNotEmpty) ...[
            const SizedBox(height: 14),
            CeCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_outlined, size: 18, color: CEColors.primary),
                      SizedBox(width: 8),
                      Text('MORAS APLICADAS',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < p.morasIndividuales.length; i++) ...[
                    if (i > 0) const Divider(height: 20),
                    CeMoraTile(
                      mora: p.morasIndividuales[i],
                      onCancelar: esAdmin && !p.morasIndividuales[i].cancelada
                          ? () => _cancelarMoraIndividual(context, p, p.morasIndividuales[i])
                          : null,
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          CeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 18, color: CEColors.primary),
                    SizedBox(width: 8),
                    Text('INFORMACIÓN DE CUOTAS',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _cajaCuota('CUOTAS', '${p.cuotas}')),
                    const SizedBox(width: 10),
                    Expanded(child: _cajaCuota('PLAZO', p.plazo)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: _cajaCuota('MONTO CUOTA', formatearLempiras(p.cuota),
                            color: CEColors.accent)),
                    const SizedBox(width: 10),
                    Expanded(child: _cajaCuota('DÍAS EFECTIVOS', '${p.diasEfectivos}')),
                  ],
                ),
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
                    Icon(Icons.info_outline, size: 18, color: CEColors.primary),
                    SizedBox(width: 8),
                    Text('INFORMACIÓN ADICIONAL',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 14),
                _filaFinanciera('Cobrador Asignado',
                    p.cobrador.isEmpty ? 'Sin asignar' : p.cobrador),
                if (p.fecha != null)
                  _filaFinanciera('Fecha inicio', formatoFecha.format(p.fecha!.toDate())),
                if (p.lugar.isNotEmpty) _filaFinanciera('Lugar', p.lugar),
                if (p.garantia.isNotEmpty) _filaFinanciera('Garantía', p.garantia),
                if (p.observaciones.isNotEmpty) _filaFinanciera('Observaciones', p.observaciones),
              ],
            ),
          ),
          if (p.fotos.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('Fotos', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: p.fotos
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
          const SizedBox(height: 20),
          if (!p.eliminado && p.estado != 'saldado') ...[
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => irAPantalla(context,
                    ruta: '/prestamos/${p.prestamoId}/cobrar',
                    pantalla: CobrarScreen(prestamoId: p.prestamoId)),
                style: ElevatedButton.styleFrom(shape: const StadiumBorder()),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Cobrar'),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () => irAPantalla(context,
                  ruta: '/prestamos/${p.prestamoId}/cuotas',
                  pantalla: VerCuotasScreen(prestamoId: p.prestamoId)),
              icon: const Icon(Icons.list_alt_outlined),
              label: const Text('Ver Cuotas del Préstamo'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () => irAPantalla(context,
                  ruta: '/prestamos/${p.prestamoId}/pagos?numero=${p.numeroPrestamo}',
                  pantalla: HistorialPagosPrestamoScreen(
                      prestamoId: p.prestamoId, numeroPrestamo: p.numeroPrestamo)),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Historial de Pagos'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () => _reimprimir(context, p),
              icon: const Icon(Icons.print_outlined),
              label: const Text('Reimprimir Recibo del Préstamo'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _filaFinanciera(String label, String valor, {Color? color, bool negrita = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
                fontSize: negrita ? 16 : 13,
                color: color ?? CEColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cajaCuota(String label, String valor, {Color color = CEColors.textPrimary}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CEColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: CEColors.textSecondary)),
          const SizedBox(height: 4),
          Text(valor, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: color)),
        ],
      ),
    );
  }
}
