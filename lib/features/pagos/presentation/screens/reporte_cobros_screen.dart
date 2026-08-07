import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/roles.dart';
import '../../../../core/models/pago_model.dart';
import '../../../../core/models/prestamo_model.dart';
import '../../../../core/models/usuario_simple.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/normalizar_texto.dart';
import '../../../../core/utils/prestamo_estado_utils.dart';
import '../../../../core/widgets/ce_card.dart';
import '../../../../core/widgets/ce_scaffold.dart';
import '../../../../core/widgets/ce_stat_card.dart';
import '../../../../core/widgets/pdf_preview_screen.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../prestamos/providers/prestamos_provider.dart';
import '../../../usuarios/providers/usuarios_provider.dart';
import '../../data/reporte_cobros_pdf_service.dart';
import '../../providers/pagos_provider.dart';

enum _Modo { pagos, saldados }

const _fechasFiltro = ['Hoy', 'Semana', 'Mes', 'Todos'];

class ReporteCobrosScreen extends ConsumerStatefulWidget {
  const ReporteCobrosScreen({super.key});

  @override
  ConsumerState<ReporteCobrosScreen> createState() => _ReporteCobrosScreenState();
}

class _ReporteCobrosScreenState extends ConsumerState<ReporteCobrosScreen> {
  _Modo _modo = _Modo.pagos;
  bool _cargando = true;
  bool _esAdmin = true;
  String? _cobradorUid;

  List<PagoModel> _pagos = [];
  List<PrestamoModel> _saldados = [];
  List<UsuarioSimple> _cobradores = [];

  final _busquedaCtrl = TextEditingController();
  String _filtroFecha = 'Hoy';
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

  (DateTime?, DateTime?) get _rango {
    final hoy = DateTime.now();
    switch (_filtroFecha) {
      case 'Hoy':
        return (DateTime(hoy.year, hoy.month, hoy.day), hoy);
      case 'Semana':
        return (hoy.subtract(const Duration(days: 7)), hoy);
      case 'Mes':
        return (DateTime(hoy.year, hoy.month, 1), hoy);
      default:
        return (null, null);
    }
  }

  Future<void> _init() async {
    final usuario = ref.read(authProvider).usuario;
    _esAdmin = usuario?.rol == Roles.admin;
    _cobradorUid = _esAdmin ? null : usuario?.uid;
    if (_esAdmin) {
      _cobradores = await ref.read(usuarioRepositoryProvider).obtenerCobradores();
    }
    await _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final cobradorUid = _filtroCobradorUid ?? _cobradorUid;

    if (_modo == _Modo.pagos) {
      final (inicio, fin) = _rango;
      final pagos = await ref
          .read(pagoRepositoryProvider)
          .obtenerConRango(inicio: inicio, fin: fin, cobradorUid: cobradorUid);
      if (!mounted) return;
      setState(() {
        _pagos = pagos;
        _cargando = false;
      });
    } else {
      final prestamos =
          await ref.read(prestamoRepositoryProvider).obtenerTodos(cobradorUid: cobradorUid);
      if (!mounted) return;
      setState(() {
        _saldados = prestamos.where((p) => estadoEfectivoPrestamo(p) == 'saldado').toList();
        _cargando = false;
      });
    }
  }

  List<PagoModel> get _pagosFiltrados {
    final q = normalizarTexto(_busquedaCtrl.text);
    if (q.isEmpty) return _pagos;
    return _pagos.where((p) => normalizarTexto(p.clienteNombre).contains(q)).toList();
  }

  List<PrestamoModel> get _saldadosFiltrados {
    final q = normalizarTexto(_busquedaCtrl.text);
    if (q.isEmpty) return _saldados;
    return _saldados.where((p) => normalizarTexto(p.cliente).contains(q)).toList();
  }

  void _exportarPdf() {
    final f = DateFormat('dd/MM/yyyy HH:mm');
    if (_modo == _Modo.pagos) {
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
        titulo: 'Reporte de Cobros',
        nombreArchivo: 'reporte_cobros.pdf',
        generar: () => ReporteCobrosPdfService.generarPagos(
          filas: filas,
          filtroTexto: 'Período: $_filtroFecha',
        ),
      );
    } else {
      final ff = DateFormat('dd/MM/yyyy');
      final filas = _saldadosFiltrados
          .map((p) => FilaPrestamoSaldado(
                cliente: p.cliente,
                numeroPrestamo: p.numeroPrestamo,
                prestado: p.totalPagar > 0 ? p.totalPagar : (p.monto + p.interes),
                abonado: p.montoPagado,
                fechaCreacion: p.fechaCreacion != null ? ff.format(p.fechaCreacion!.toDate()) : '—',
              ))
          .toList();
      abrirVistaPreviaPdf(
        context,
        titulo: 'Préstamos Saldados',
        nombreArchivo: 'prestamos_saldados.pdf',
        generar: () => ReporteCobrosPdfService.generarSaldados(
          filas: filas,
          filtroTexto: 'Préstamos completados',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CeScaffold(
      maxWidth: 1000,
      appBar: AppBar(
        title: const Text('Reporte de Cobros'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Exportar PDF',
            onPressed: _cargando ? null : _exportarPdf,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: CeCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<_Modo>(
                    segments: const [
                      ButtonSegment(value: _Modo.pagos, label: Text('Pagos Realizados')),
                      ButtonSegment(value: _Modo.saldados, label: Text('Saldados')),
                    ],
                    selected: {_modo},
                    onSelectionChanged: (s) {
                      setState(() => _modo = s.first);
                      _cargar();
                    },
                  ),
                  const SizedBox(height: 12),
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
                  if (_modo == _Modo.pagos) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _fechasFiltro
                          .map((e) => ChoiceChip(
                                label: Text(e),
                                selected: _filtroFecha == e,
                                onSelected: (_) {
                                  setState(() => _filtroFecha = e);
                                  _cargar();
                                },
                              ))
                          .toList(),
                    ),
                  ],
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
          ),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _modo == _Modo.pagos
                    ? _listaPagos()
                    : _listaSaldados(),
          ),
        ],
      ),
    );
  }

  Widget _listaPagos() {
    final filas = _pagosFiltrados;
    final totalAbonos = filas.fold<double>(0, (a, p) => a + p.monto);
    final totalMora = filas.fold<double>(0, (a, p) => a + p.mora);
    final f = DateFormat('dd/MM/yyyy hh:mm a');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.15,
          children: [
            CeStatCard(icono: Icons.receipt_long_outlined, valor: '${filas.length}', etiqueta: 'Pagos'),
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
                child: CeCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.clienteNombre.isEmpty ? 'Cliente' : p.clienteNombre,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text('N° ${p.numeroPrestamo} · ${p.nombreCobrador}',
                                style: const TextStyle(fontSize: 11, color: CEColors.textSecondary)),
                            if (p.fechaPago != null)
                              Text(f.format(p.fechaPago!.toDate()),
                                  style: const TextStyle(fontSize: 11, color: CEColors.textSecondary)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(formatearLempiras(p.total),
                              style: const TextStyle(fontWeight: FontWeight.w800, color: CEColors.accent)),
                          if (p.mora > 0)
                            Text('incl. ${formatearLempiras(p.mora)} mora',
                                style: const TextStyle(fontSize: 10, color: CEColors.danger)),
                        ],
                      ),
                    ],
                  ),
                ),
              )),
      ],
    );
  }

  Widget _listaSaldados() {
    final filas = _saldadosFiltrados;
    final f = DateFormat('dd/MM/yyyy');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        CeStatCard(icono: Icons.check_circle_outline, valor: '${filas.length}', etiqueta: 'Préstamos saldados', color: CEColors.success),
        const SizedBox(height: 16),
        if (filas.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(child: Text('No hay préstamos saldados')),
          )
        else
          ...filas.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CeCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.cliente, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text('N° ${p.numeroPrestamo}',
                                style: const TextStyle(fontSize: 11, color: CEColors.textSecondary)),
                            if (p.fechaCreacion != null)
                              Text(f.format(p.fechaCreacion!.toDate()),
                                  style: const TextStyle(fontSize: 11, color: CEColors.textSecondary)),
                          ],
                        ),
                      ),
                      Text(formatearLempiras(p.montoPagado),
                          style: const TextStyle(fontWeight: FontWeight.w800, color: CEColors.success)),
                    ],
                  ),
                ),
              )),
      ],
    );
  }
}
