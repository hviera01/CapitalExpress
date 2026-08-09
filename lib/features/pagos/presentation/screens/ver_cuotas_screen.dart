import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/roles.dart';
import '../../../../core/models/pago_model.dart';
import '../../../../core/models/prestamo_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/cuotas_calculos.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/ce_card.dart';
import '../../../../core/widgets/ce_data_table_style.dart';
import '../../../../core/widgets/ce_scaffold.dart';
import '../../../../core/widgets/ce_web_nav.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../prestamos/providers/prestamos_provider.dart';
import '../../data/cuotas_pdf_service.dart';
import '../../providers/pagos_provider.dart';
import '../../../../core/widgets/pdf_preview_screen.dart';
import 'cobrar_screen.dart';

/// "Ver Cuotas": tabla de cuotas de un prestamo, reconstruida en vivo a
/// partir de los pagos reales. Si el cliente da menos de una cuota
/// queda "parcial"; si da mas, esa cuota se completa y el resto ya
/// quedo aplicado a la siguiente (eso lo resuelve la cascada al
/// registrar el pago, aca solo se refleja el resultado).
class VerCuotasScreen extends ConsumerStatefulWidget {
  final String prestamoId;

  const VerCuotasScreen({super.key, required this.prestamoId});

  @override
  ConsumerState<VerCuotasScreen> createState() => _VerCuotasScreenState();
}

class _VerCuotasScreenState extends ConsumerState<VerCuotasScreen> {
  late final Stream<PrestamoModel?> _streamPrestamo =
      ref.read(prestamoRepositoryProvider).streamPorId(widget.prestamoId);
  late final Stream<List<PagoModel>> _streamPagos =
      ref.read(pagoRepositoryProvider).streamPorPrestamo(widget.prestamoId);

  void _exportarPdf(PrestamoModel prestamo, List<CuotaInfo> cuotas) {
    abrirVistaPreviaPdf(
      context,
      titulo: 'Cuotas del Préstamo',
      nombreArchivo: 'cuotas_${prestamo.numeroPrestamo}.pdf',
      generar: () => CuotasPdfService.generar(
        cliente: prestamo.cliente,
        numeroPrestamo: prestamo.numeroPrestamo,
        cuotas: cuotas,
        mora: prestamo.mora,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PrestamoModel?>(
      stream: _streamPrestamo,
      builder: (context, prestamoSnap) {
        if (prestamoSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final prestamo = prestamoSnap.data;
        if (prestamo == null) {
          return const Scaffold(body: Center(child: Text('Préstamo no encontrado')));
        }
        return StreamBuilder<List<PagoModel>>(
          stream: _streamPagos,
          builder: (context, pagosSnap) {
            final pagos = pagosSnap.data ?? const [];
            final cuotas = construirTablaCuotas(prestamo, pagos);
            return _contenido(context, prestamo, cuotas);
          },
        );
      },
    );
  }

  Widget _contenido(BuildContext context, PrestamoModel prestamo, List<CuotaInfo> cuotas) {
    final esAdmin = Roles.esAdminOEquivalente(ref.watch(authProvider).usuario?.rol);
    final completadas = cuotas.where((c) => c.estado == EstadoCuota.pagada).length;
    final parciales = cuotas.where((c) => c.estado == EstadoCuota.parcial).length;
    final pendientes = cuotas.where((c) => c.estado == EstadoCuota.pendiente).length;
    final progreso = cuotas.isEmpty ? 0.0 : completadas / cuotas.length;
    final f = DateFormat('dd/MM/yyyy');

    return CeScaffold(
      maxWidth: 720,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Sistema de Cuotas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Exportar PDF',
            onPressed: () => _exportarPdf(prestamo, cuotas),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(prestamo.cliente, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Text('N° ${prestamo.numeroPrestamo} · ${prestamo.plazo}',
                    style: const TextStyle(fontSize: 12, color: CEColors.textSecondary)),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progreso,
                    minHeight: 8,
                    backgroundColor: CEColors.border,
                    color: CEColors.success,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$completadas de ${cuotas.length} cuotas completadas',
                        style: const TextStyle(fontSize: 12, color: CEColors.textSecondary)),
                    Text('${(progreso * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _mini('$completadas', 'Completadas', CEColors.success)),
              const SizedBox(width: 10),
              Expanded(child: _mini('$parciales', 'Parciales', CEColors.accent)),
              const SizedBox(width: 10),
              Expanded(child: _mini('$pendientes', 'Pendientes', CEColors.danger)),
            ],
          ),
          if (prestamo.mora > 0) ...[
            const SizedBox(height: 12),
            CeCard(
              color: CEColors.danger.withValues(alpha: 0.06),
              borderColor: CEColors.danger.withValues(alpha: 0.3),
              child: Row(
                children: [
                  const Icon(Icons.report_gmailerrorred_outlined, color: CEColors.danger, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Mora aplicada', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  Text(formatearLempiras(prestamo.mora),
                      style: const TextStyle(fontWeight: FontWeight.w800, color: CEColors.danger)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text('Sistema de pagos en cascada',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 12),
            child: Text(
              'Los pagos se distribuyen automáticamente completando cuotas en orden: '
              'si el cliente da menos de una cuota, queda parcial; si da más, se completa '
              'y el resto pasa a la siguiente.',
              style: TextStyle(fontSize: 12, color: CEColors.textSecondary),
            ),
          ),
          if (esEscritorioWeb(context))
            _TablaCuotas(cuotas: cuotas, fechaFormato: f, prestamoId: prestamo.prestamoId)
          else
            ...cuotas.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _CuotaTile(
                    cuota: c,
                    esAdmin: esAdmin,
                    fechaFormato: f,
                    onCobrar: c.estado != EstadoCuota.pagada
                        ? () => irAPantalla(context,
                            ruta:
                                '/prestamos/${prestamo.prestamoId}/cobrar?monto=${c.faltante.toStringAsFixed(2)}',
                            pantalla: CobrarScreen(
                                prestamoId: prestamo.prestamoId, montoInicial: c.faltante))
                        : null,
                  ),
                )),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _mini(String valor, String etiqueta, Color color) {
    return CeCard(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Text(valor, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: color)),
          const SizedBox(height: 2),
          Text(etiqueta, style: const TextStyle(fontSize: 11, color: CEColors.textSecondary)),
        ],
      ),
    );
  }
}

/// Version tabla de la lista de cuotas, solo para escritorio Web (ver
/// esEscritorioWeb).
class _TablaCuotas extends StatelessWidget {
  final List<CuotaInfo> cuotas;
  final DateFormat fechaFormato;
  final String prestamoId;

  const _TablaCuotas({required this.cuotas, required this.fechaFormato, required this.prestamoId});

  Color _color(EstadoCuota estado) {
    switch (estado) {
      case EstadoCuota.pagada:
        return CEColors.success;
      case EstadoCuota.parcial:
        return CEColors.accent;
      case EstadoCuota.pendiente:
        return CEColors.danger;
    }
  }

  String _etiqueta(EstadoCuota estado) {
    switch (estado) {
      case EstadoCuota.pagada:
        return 'PAGADA';
      case EstadoCuota.parcial:
        return 'PARCIAL';
      case EstadoCuota.pendiente:
        return 'PENDIENTE';
    }
  }

  @override
  Widget build(BuildContext context) {
    return CeDataTableCard(
      columns: const [
        DataColumn(label: Text('Cuota')),
        DataColumn(label: Text('Vence')),
        DataColumn(label: Text('Pagado / Esperado')),
        DataColumn(label: Text('Estado')),
        DataColumn(label: Text('Acción')),
      ],
      rows: cuotas.map((c) {
            return DataRow(cells: [
              DataCell(Text('#${c.numero}', style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text(fechaFormato.format(c.fechaVencimiento))),
              DataCell(Text(
                  '${formatearLempiras(c.montoPagado)} de ${formatearLempiras(c.montoEsperado)}')),
              DataCell(ceTableBadge(_etiqueta(c.estado), _color(c.estado))),
              DataCell(c.estado != EstadoCuota.pagada
                  ? TextButton(
                      onPressed: () => irAPantalla(context,
                          ruta: '/prestamos/$prestamoId/cobrar?monto=${c.faltante.toStringAsFixed(2)}',
                          pantalla: CobrarScreen(prestamoId: prestamoId, montoInicial: c.faltante)),
                      child: Text(c.estado == EstadoCuota.parcial ? 'Completar' : 'Cobrar'),
                    )
                  : const Text('—')),
            ]);
          }).toList(),
    );
  }
}

class _CuotaTile extends StatelessWidget {
  final CuotaInfo cuota;
  final bool esAdmin;
  final DateFormat fechaFormato;
  final VoidCallback? onCobrar;

  const _CuotaTile({
    required this.cuota,
    required this.esAdmin,
    required this.fechaFormato,
    required this.onCobrar,
  });

  Color get _color {
    switch (cuota.estado) {
      case EstadoCuota.pagada:
        return CEColors.success;
      case EstadoCuota.parcial:
        return CEColors.accent;
      case EstadoCuota.pendiente:
        return CEColors.danger;
    }
  }

  String get _etiqueta {
    switch (cuota.estado) {
      case EstadoCuota.pagada:
        return 'PAGADA';
      case EstadoCuota.parcial:
        return 'PARCIAL';
      case EstadoCuota.pendiente:
        return 'PENDIENTE';
    }
  }

  @override
  Widget build(BuildContext context) {
    return CeCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Cuota #${cuota.numero}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(_etiqueta,
                          style: TextStyle(fontSize: 10, color: _color, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Vence: ${fechaFormato.format(cuota.fechaVencimiento)}',
                    style: const TextStyle(fontSize: 11, color: CEColors.textSecondary)),
                Text(
                  '${formatearLempiras(cuota.montoPagado)} de ${formatearLempiras(cuota.montoEsperado)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          if (onCobrar != null)
            OutlinedButton(
              onPressed: onCobrar,
              child: Text(cuota.estado == EstadoCuota.parcial ? 'Completar' : 'Cobrar'),
            ),
        ],
      ),
    );
  }
}
