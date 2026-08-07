import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/roles.dart';
import '../../../../core/models/pago_model.dart';
import '../../../../core/models/usuario_simple.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/normalizar_texto.dart';
import '../../../../core/widgets/ce_card.dart';
import '../../../../core/widgets/ce_scaffold.dart';
import '../../../../core/widgets/ce_stat_card.dart';
import '../../../../core/widgets/filtro_fecha_rango.dart';
import '../../../../core/widgets/pdf_preview_screen.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../usuarios/providers/usuarios_provider.dart';
import '../../data/reporte_cobros_pdf_service.dart';
import '../../providers/pagos_provider.dart';
import '../widgets/pago_tile.dart';

/// Historial de Pagos (antes tenia un modo "Saldados" separado -- se
/// saco, esta pantalla es solo el historial de abonos con Reimprimir/
/// Eliminar por fila).
class ReporteCobrosScreen extends ConsumerStatefulWidget {
  const ReporteCobrosScreen({super.key});

  @override
  ConsumerState<ReporteCobrosScreen> createState() => _ReporteCobrosScreenState();
}

class _ReporteCobrosScreenState extends ConsumerState<ReporteCobrosScreen> {
  bool _cargando = true;
  bool _esAdmin = true;
  String? _cobradorUid;

  List<PagoModel> _pagos = [];
  List<UsuarioSimple> _cobradores = [];

  final _busquedaCtrl = TextEditingController();
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  String? _filtroCobradorUid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final usuario = ref.read(authProvider).usuario;
    _esAdmin = usuario?.rol == Roles.admin;
    _cobradorUid = _esAdmin ? null : usuario?.uid;
    if (_esAdmin) {
      _cobradores = await ref.read(usuarioRepositoryProvider).obtenerCobradores();
    }
    final hoy = DateTime.now();
    _fechaInicio = DateTime(hoy.year, hoy.month, hoy.day);
    _fechaFin = hoy;
    await _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final cobradorUid = _filtroCobradorUid ?? _cobradorUid;
    final pagos = await ref
        .read(pagoRepositoryProvider)
        .obtenerConRango(inicio: _fechaInicio, fin: _fechaFin, cobradorUid: cobradorUid);
    if (!mounted) return;
    setState(() {
      _pagos = pagos;
      _cargando = false;
    });
  }

  List<PagoModel> get _pagosFiltrados {
    final q = normalizarTexto(_busquedaCtrl.text);
    if (q.isEmpty) return _pagos;
    return _pagos.where((p) => normalizarTexto(p.clienteNombre).contains(q)).toList();
  }

  void _exportarPdf() {
    final f = DateFormat('dd/MM/yyyy HH:mm');
    final filas = _pagosFiltrados
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
      nombreArchivo: 'historial_pagos.pdf',
      generar: () => ReporteCobrosPdfService.generarPagos(
        filas: filas,
        filtroTexto: 'Período: $_filtroTexto',
      ),
    );
  }

  String get _filtroTexto {
    final f = DateFormat('dd/MM/yyyy');
    if (_fechaInicio == null && _fechaFin == null) return 'Todo el período';
    final ini = _fechaInicio != null ? f.format(_fechaInicio!) : '…';
    final fin = _fechaFin != null ? f.format(_fechaFin!) : '…';
    return 'Del $ini al $fin';
  }

  @override
  Widget build(BuildContext context) {
    final filas = _pagosFiltrados;
    final totalAbonos = filas.fold<double>(0, (a, p) => a + p.monto);
    final totalMora = filas.fold<double>(0, (a, p) => a + p.mora);

    return CeScaffold(
      maxWidth: 1000,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Historial de Pagos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Exportar PDF',
            onPressed: _cargando ? null : _exportarPdf,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                CeCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _busquedaCtrl,
                        decoration: InputDecoration(
                          hintText: 'Buscar cliente',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(_busquedaCtrl.clear),
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      FiltroFechaRango(
                        fechaInicio: _fechaInicio,
                        fechaFin: _fechaFin,
                        onCambio: (inicio, fin) {
                          setState(() {
                            _fechaInicio = inicio;
                            _fechaFin = fin;
                          });
                          _cargar();
                        },
                      ),
                      if (_esAdmin && _cobradores.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String?>(
                          initialValue: _filtroCobradorUid,
                          decoration: const InputDecoration(labelText: 'Cobrador'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Todos los cobradores')),
                            ..._cobradores
                                .map((c) => DropdownMenuItem(value: c.uid, child: Text(c.nombre))),
                          ],
                          onChanged: (v) {
                            setState(() => _filtroCobradorUid = v);
                            _cargar();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.15,
                  children: [
                    CeStatCard(
                        icono: Icons.receipt_long_outlined,
                        valor: '${filas.length}',
                        etiqueta: 'Pagos'),
                    CeStatCard(
                        icono: Icons.savings_outlined,
                        valor: formatearLempiras(totalAbonos),
                        etiqueta: 'Abonos',
                        color: CEColors.success),
                    CeStatCard(
                        icono: Icons.report_gmailerrorred_outlined,
                        valor: formatearLempiras(totalMora),
                        etiqueta: 'Mora',
                        color: CEColors.danger),
                  ],
                ),
                const SizedBox(height: 16),
                if (filas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(child: Text('No hay pagos en este período')),
                  )
                else
                  ...filas.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: PagoTile(
                          pago: p,
                          onEliminado: () => setState(() => _pagos.removeWhere((x) => x.docId == p.docId)),
                        ),
                      )),
              ],
            ),
    );
  }
}
