import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/roles.dart';
import '../../../../core/models/prestamo_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/normalizar_texto.dart';
import '../../../../core/utils/prestamo_estado_utils.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/ce_card.dart';
import '../../../../core/widgets/ce_data_table_style.dart';
import '../../../../core/widgets/ce_scaffold.dart';
import '../../../../core/widgets/ce_stat_card.dart';
import '../../../../core/widgets/ce_web_nav.dart';
import '../../../../core/widgets/filtro_fecha_rango.dart';
import '../../../../core/widgets/pdf_preview_screen.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../data/reporte_prestamos_pdf_service.dart';
import 'prestamo_detalle_screen.dart';
import '../../providers/prestamos_provider.dart';
import '../../providers/reporte_prestamos_cache.dart';

const _estadosFiltro = ['Todos', 'activo', 'vencido', 'saldado'];

class ReportePrestamosScreen extends ConsumerStatefulWidget {
  const ReportePrestamosScreen({super.key});

  @override
  ConsumerState<ReportePrestamosScreen> createState() => _ReportePrestamosScreenState();
}

class _ReportePrestamosScreenState extends ConsumerState<ReportePrestamosScreen> {
  bool _cargando = true;
  List<PrestamoModel> _prestamos = [];
  final _busquedaCtrl = TextEditingController();
  String _filtroEstado = 'Todos';
  DateTime? _fechaInicio;
  DateTime? _fechaFin;

  @override
  void initState() {
    super.initState();
    // Cache es SOLO para escritorio Web -- ver ClientesListScreen
    // (mismo patron). En mobile/Windows cada entrada arranca en
    // blanco y recarga todo, como siempre.
    if (esEscritorioWeb(context)) {
      final cache = ref.read(reportePrestamosCacheProvider);
      if (cache.tieneDatos) {
        _prestamos = List.of(cache.prestamos);
        _cargando = false;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final usuario = ref.read(authProvider).usuario;
    final esAdmin = usuario?.rol == Roles.admin;
    final primeraVez = !esEscritorioWeb(context) || _prestamos.isEmpty;
    if (primeraVez) {
      setState(() => _cargando = true);
    }
    final prestamos = await ref
        .read(prestamoRepositoryProvider)
        .obtenerTodos(cobradorUid: esAdmin ? null : usuario?.uid);
    if (!mounted) return;
    setState(() {
      _prestamos = prestamos;
      _cargando = false;
    });
    if (esEscritorioWeb(context)) {
      final cache = ref.read(reportePrestamosCacheProvider);
      cache
        ..tieneDatos = true
        ..prestamos = prestamos;
    }
  }

  bool _pasaFecha(PrestamoModel p) {
    if (_fechaInicio == null && _fechaFin == null) return true;
    final fecha = p.fechaCreacion?.toDate();
    if (fecha == null) return false;
    if (_fechaInicio != null && fecha.isBefore(_fechaInicio!)) return false;
    if (_fechaFin != null) {
      final finInclusive =
          DateTime(_fechaFin!.year, _fechaFin!.month, _fechaFin!.day, 23, 59, 59);
      if (fecha.isAfter(finInclusive)) return false;
    }
    return true;
  }

  String get _filtroFechaTexto {
    final f = DateFormat('dd/MM/yyyy');
    if (_fechaInicio == null && _fechaFin == null) return 'Todo el período';
    final ini = _fechaInicio != null ? f.format(_fechaInicio!) : '…';
    final fin = _fechaFin != null ? f.format(_fechaFin!) : '…';
    return 'Del $ini al $fin';
  }

  List<PrestamoModel> get _filtrados {
    var lista = _prestamos;
    if (_filtroEstado != 'Todos') {
      lista = lista.where((p) => estadoEfectivoPrestamo(p) == _filtroEstado).toList();
    }
    lista = lista.where(_pasaFecha).toList();
    final q = normalizarTexto(_busquedaCtrl.text);
    if (q.isNotEmpty) {
      lista = lista
          .where((p) =>
              normalizarTexto(p.cliente).contains(q) || normalizarTexto(p.numeroPrestamo).contains(q))
          .toList();
    }
    return lista;
  }

  void _exportarPdf(List<PrestamoModel> filas) {
    final f = DateFormat('dd/MM/yyyy');
    final filasPdf = filas
        .map((p) => FilaReportePrestamo(
              cliente: p.cliente,
              numeroPrestamo: p.numeroPrestamo,
              estado: estadoEfectivoPrestamo(p),
              monto: p.monto,
              montoPagado: p.montoPagado,
              mora: p.mora,
              saldo: p.saldo,
              fecha: p.fechaCreacion != null ? f.format(p.fechaCreacion!.toDate()) : '—',
            ))
        .toList();

    abrirVistaPreviaPdf(
      context,
      titulo: 'Reporte de Préstamos',
      nombreArchivo: 'reporte_prestamos.pdf',
      generar: () => ReportePrestamosPdfService.generar(
        filas: filasPdf,
        filtroTexto: 'Estado: $_filtroEstado  ·  $_filtroFechaTexto',
      ),
    );
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'saldado':
        return CEColors.success;
      case 'vencido':
        return CEColors.danger;
      default:
        return CEColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filas = _cargando ? const <PrestamoModel>[] : _filtrados;
    final activos = filas.where((p) => estadoEfectivoPrestamo(p) != 'saldado').length;
    final vencidos = filas.where((p) => estadoEfectivoPrestamo(p) == 'vencido').length;
    final montoPrestado = filas.fold<double>(0, (a, p) => a + p.monto);
    final montoPagado = filas.fold<double>(0, (a, p) => a + p.montoPagado);
    final mora = filas.fold<double>(0, (a, p) => a + p.mora);
    final pendiente = filas.fold<double>(0, (a, p) => a + p.saldo);
    final formatoFecha = DateFormat('dd/MM/yyyy');

    return CeScaffold(
      maxWidth: 1000,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Reporte de Préstamos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Exportar PDF',
            onPressed: _cargando ? null : () => _exportarPdf(filas),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                CeCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _busquedaCtrl,
                        decoration: InputDecoration(
                          hintText: 'Buscar cliente o número',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(_busquedaCtrl.clear),
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _estadosFiltro
                            .map((e) => ChoiceChip(
                                  label: Text(e == 'Todos' ? e : e[0].toUpperCase() + e.substring(1)),
                                  selected: _filtroEstado == e,
                                  onSelected: (_) => setState(() => _filtroEstado = e),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 8),
                      FiltroFechaRango(
                        fechaInicio: _fechaInicio,
                        fechaFin: _fechaFin,
                        onCambio: (inicio, fin) => setState(() {
                          _fechaInicio = inicio;
                          _fechaFin = fin;
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                CeStatGrid(
                  mobileCrossAxisCount: 3,
                  mobileChildAspectRatio: 1.15,
                  items: [
                    CeStatItem(icono: Icons.list_alt_outlined, valor: '${filas.length}', etiqueta: 'Total'),
                    CeStatItem(
                        icono: Icons.trending_up,
                        valor: '$activos',
                        etiqueta: 'Activos',
                        color: CEColors.accent),
                    CeStatItem(
                        icono: Icons.warning_amber_outlined,
                        valor: '$vencidos',
                        etiqueta: 'Vencidos',
                        color: CEColors.danger),
                    CeStatItem(
                        icono: Icons.account_balance_outlined,
                        valor: formatearLempiras(montoPrestado),
                        etiqueta: 'Prestado'),
                    CeStatItem(
                        icono: Icons.savings_outlined,
                        valor: formatearLempiras(montoPagado),
                        etiqueta: 'Pagado',
                        color: CEColors.success),
                    CeStatItem(
                        icono: Icons.account_balance_wallet_outlined,
                        valor: formatearLempiras((pendiente - mora).clamp(0, double.infinity)),
                        etiqueta: 'Pendiente sin mora',
                        color: CEColors.danger),
                    CeStatItem(
                        icono: Icons.report_gmailerrorred_outlined,
                        valor: formatearLempiras(mora),
                        etiqueta: 'Mora',
                        color: CEColors.danger),
                    CeStatItem(
                        icono: Icons.warning_amber_outlined,
                        valor: formatearLempiras(pendiente),
                        etiqueta: 'Pendiente con mora',
                        color: CEColors.danger),
                  ],
                ),
                const SizedBox(height: 16),
                if (filas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(child: Text('No hay préstamos con este filtro')),
                  )
                else if (esEscritorioWeb(context))
                  _TablaReportePrestamos(filas: filas, formatoFecha: formatoFecha)
                else
                  ...filas.map((p) {
                    final estado = estadoEfectivoPrestamo(p);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: CeCard(
                        onTap: () => irAPantalla(context,
                            ruta: '/prestamos/${p.prestamoId}',
                            pantalla: PrestamoDetalleScreen(prestamoId: p.prestamoId, prestamoInicial: p)),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.cliente,
                                      style: const TextStyle(fontWeight: FontWeight.w700)),
                                  Text('N° ${p.numeroPrestamo}',
                                      style: const TextStyle(
                                          fontSize: 12, color: CEColors.textSecondary)),
                                  if (p.fechaCreacion != null)
                                    Text(formatoFecha.format(p.fechaCreacion!.toDate()),
                                        style: const TextStyle(
                                            fontSize: 11, color: CEColors.textSecondary)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(formatearLempiras(p.saldo),
                                    style: const TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _colorEstado(estado).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(estado,
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: _colorEstado(estado),
                                          fontWeight: FontWeight.w700)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}

/// Version tabla del Reporte de Prestamos, solo para escritorio Web
/// (ver esEscritorioWeb).
class _TablaReportePrestamos extends StatelessWidget {
  final List<PrestamoModel> filas;
  final DateFormat formatoFecha;

  const _TablaReportePrestamos({required this.filas, required this.formatoFecha});

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'saldado':
        return CEColors.success;
      case 'vencido':
        return CEColors.danger;
      default:
        return CEColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CeDataTableCard(
      columns: const [
        DataColumn(label: Text('Cliente')),
        DataColumn(label: Text('N°')),
        DataColumn(label: Text('Fecha')),
        DataColumn(label: Text('Saldo'), numeric: true),
        DataColumn(label: Text('Estado')),
      ],
      rows: filas.map((p) {
            final estado = estadoEfectivoPrestamo(p);
            return DataRow(
              onSelectChanged: (_) => irAPantalla(context,
                  ruta: '/prestamos/${p.prestamoId}',
                  pantalla: PrestamoDetalleScreen(prestamoId: p.prestamoId, prestamoInicial: p)),
              cells: [
                DataCell(Text(p.cliente, style: const TextStyle(fontWeight: FontWeight.w600))),
                DataCell(Text('#${p.numeroPrestamo}')),
                DataCell(Text(
                    p.fechaCreacion != null ? formatoFecha.format(p.fechaCreacion!.toDate()) : '—')),
                DataCell(Text(formatearLempiras(p.saldo),
                    style: const TextStyle(fontWeight: FontWeight.w700))),
                DataCell(ceTableBadge(estado, _colorEstado(estado))),
              ],
            );
          }).toList(),
    );
  }
}
