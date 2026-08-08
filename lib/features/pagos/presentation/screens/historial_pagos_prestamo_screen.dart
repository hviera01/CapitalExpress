import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/roles.dart';
import '../../../../core/models/pago_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/ce_scaffold.dart';
import '../../../../core/widgets/ce_stat_card.dart';
import '../../../../core/widgets/pdf_preview_screen.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../data/reporte_cobros_pdf_service.dart';
import '../../providers/pagos_provider.dart';
import '../widgets/pago_tile.dart';

/// Historial de Pagos de UN prestamo puntual (desde Ver Préstamo). En
/// vivo: si se registra o borra un pago desde otro lado, esta lista se
/// actualiza sola.
class HistorialPagosPrestamoScreen extends ConsumerStatefulWidget {
  final String prestamoId;
  final String numeroPrestamo;

  const HistorialPagosPrestamoScreen({
    super.key,
    required this.prestamoId,
    required this.numeroPrestamo,
  });

  @override
  ConsumerState<HistorialPagosPrestamoScreen> createState() =>
      _HistorialPagosPrestamoScreenState();
}

class _HistorialPagosPrestamoScreenState extends ConsumerState<HistorialPagosPrestamoScreen> {
  late final Stream<List<PagoModel>> _stream =
      ref.read(pagoRepositoryProvider).streamPorPrestamo(widget.prestamoId);

  void _exportarPdf(List<PagoModel> pagos) {
    final f = DateFormat('dd/MM/yyyy HH:mm');
    final filas = pagos
        .map((p) => FilaReporteCobro(
              cliente: p.clienteNombre,
              numeroPrestamo: p.numeroPrestamo,
              fechaPago: p.fechaPago != null ? f.format(p.fechaPago!.toDate()) : '—',
              abono: p.monto,
              mora: p.mora,
              cobrador: p.nombreCobrador.isEmpty ? 'N/D' : p.nombreCobrador,
            ))
        .toList();
    abrirVistaPreviaPdf(
      context,
      titulo: 'Historial de Pagos',
      nombreArchivo: 'historial_pagos_${widget.numeroPrestamo}.pdf',
      generar: () => ReporteCobrosPdfService.generarPagos(
        filas: filas,
        filtroTexto: 'Préstamo N° ${widget.numeroPrestamo}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esAdmin = ref.watch(authProvider).usuario?.rol == Roles.admin;
    return StreamBuilder<List<PagoModel>>(
      stream: _stream,
      builder: (context, snapshot) {
        final cargando = snapshot.connectionState == ConnectionState.waiting;
        final pagos = snapshot.data ?? const [];
        final totalAbonado = pagos.fold<double>(0, (a, p) => a + p.monto);
        final totalMora = pagos.fold<double>(0, (a, p) => a + p.mora);

        return CeScaffold(
          maxWidth: 720,
          appBar: AppBar(
            leading: const BackButton(),
            title: const Text('Historial de Pagos'),
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                tooltip: 'Exportar PDF',
                onPressed: cargando ? null : () => _exportarPdf(pagos),
              ),
            ],
          ),
          body: cargando
              ? const Center(child: CircularProgressIndicator())
              : snapshot.hasError
                  ? Center(child: Text('Error al cargar: ${snapshot.error}'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text('Préstamo N° ${widget.numeroPrestamo}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 12),
                        CeStatGrid(
                          mobileCrossAxisCount: 3,
                          mobileChildAspectRatio: 1.15,
                          children: [
                            CeStatCard(
                                icono: Icons.receipt_long_outlined,
                                valor: '${pagos.length}',
                                etiqueta: 'Pagos'),
                            CeStatCard(
                                icono: Icons.savings_outlined,
                                valor: formatearLempiras(totalAbonado),
                                etiqueta: 'Abonado',
                                color: CEColors.success),
                            CeStatCard(
                                icono: Icons.report_gmailerrorred_outlined,
                                valor: formatearLempiras(totalMora),
                                etiqueta: 'Mora',
                                color: CEColors.danger),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (pagos.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 24),
                            child: Center(child: Text('Este préstamo todavía no tiene pagos')),
                          )
                        else if (esEscritorioWeb(context))
                          TablaPagos(
                            pagos: pagos,
                            mostrarPrestamo: false,
                            puedeEliminar: esAdmin,
                            onEliminado: (_) {},
                          )
                        else
                          ...pagos.map((p) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: PagoTile(
                                  pago: p,
                                  mostrarPrestamo: false,
                                  puedeEliminar: esAdmin,
                                  onEliminado: () {},
                                ),
                              )),
                      ],
                    ),
        );
      },
    );
  }
}
