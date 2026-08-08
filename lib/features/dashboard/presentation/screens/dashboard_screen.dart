import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/ce_card.dart';
import '../../../../core/widgets/ce_scaffold.dart';
import '../../../../core/widgets/ce_section_label.dart';
import '../../../../core/widgets/ce_stat_card.dart';
import '../../../../core/widgets/filtro_fecha_rango.dart';
import '../../../../core/widgets/pdf_preview_screen.dart';
import '../../../../core/models/pago_model.dart';
import '../../../clientes/providers/clientes_provider.dart';
import '../../../pagos/providers/pagos_provider.dart';
import '../../../prestamos/providers/prestamos_provider.dart';
import '../../data/dashboard_pdf_service.dart';

/// Clientes/Prestado/Interes/Pendiente son SIEMPRE sobre el universo
/// completo (no se filtran por fecha, son un saldo actual, no algo que
/// tenga sentido acotar a un periodo); solo Cobros/Pagado/Moras
/// Cobradas salen del rango de fechas elegido. "Pendiente" usa el
/// mismo campo `saldo` que Reporte de Clientes y Reporte de Prestamos
/// (ver core/utils/reporte_clientes_calculos.dart) para que el numero
/// sea siempre el mismo en toda la app.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  bool _cargando = true;
  String? _error;

  int _totalClientes = 0;
  double _totalPrestado = 0;
  double _totalInteres = 0;
  double _totalPendiente = 0;
  int _totalCobros = 0;
  double _totalPagado = 0;
  double _totalMoras = 0;
  int _cantidadMoras = 0;
  Map<String, double> _porCobrador = {};

  int _prestamosActivos = 0;
  int _prestamosMora = 0;
  int _prestamosSaldados = 0;

  int get _totalPrestamos => _prestamosActivos + _prestamosMora + _prestamosSaldados;

  double get _tasaCobro {
    final base = _totalPagado + _totalPendiente;
    return base > 0 ? (_totalPagado / base) * 100 : 0;
  }

  double get _carteraEnMoraPct =>
      _totalPrestamos > 0 ? (_prestamosMora / _totalPrestamos) * 100 : 0;

  double get _prestamoPromedio => _totalPrestamos > 0 ? _totalPrestado / _totalPrestamos : 0;

  double get _rentabilidad => _totalPrestado > 0 ? (_totalInteres / _totalPrestado) * 100 : 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final prestamoRepo = ref.read(prestamoRepositoryProvider);
      final resultados = await Future.wait([
        ref.read(clienteRepositoryProvider).contar(),
        prestamoRepo.sumarMontoEInteres(),
        ref.read(pagoRepositoryProvider).obtenerConRango(inicio: _fechaInicio, fin: _fechaFin),
        prestamoRepo.sumarSaldoPendiente(),
        prestamoRepo.contarPorEstado('activo'),
        prestamoRepo.contarPorEstado('mora'),
        prestamoRepo.contarPorEstado('saldado'),
      ]);

      final totalClientes = resultados[0] as int;
      final montoEInteres = resultados[1] as ({double monto, double interes});
      final pagos = resultados[2] as List<PagoModel>;
      final totalPendiente = resultados[3] as double;
      final activos = resultados[4] as int;
      final enMora = resultados[5] as int;
      final saldados = resultados[6] as int;

      double totalPagado = 0, totalMoras = 0;
      var cantidadMoras = 0;
      final porCobrador = <String, double>{};
      for (final p in pagos) {
        totalPagado += p.monto;
        totalMoras += p.mora;
        if (p.mora > 0) cantidadMoras++;
        final nombre = p.nombreCobrador.isEmpty ? 'Desconocido' : p.nombreCobrador;
        porCobrador[nombre] = (porCobrador[nombre] ?? 0) + p.monto;
      }

      if (!mounted) return;
      setState(() {
        _totalClientes = totalClientes;
        _totalPrestado = montoEInteres.monto;
        _totalInteres = montoEInteres.interes;
        _totalPendiente = totalPendiente;
        _totalCobros = pagos.length;
        _totalPagado = totalPagado;
        _totalMoras = totalMoras;
        _cantidadMoras = cantidadMoras;
        _porCobrador = porCobrador;
        _prestamosActivos = activos;
        _prestamosMora = enMora;
        _prestamosSaldados = saldados;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _cargando = false;
      });
    }
  }

  String get _filtroTexto {
    final f = DateFormat('dd/MM/yyyy');
    if (_fechaInicio == null && _fechaFin == null) return 'Todo el período';
    final ini = _fechaInicio != null ? f.format(_fechaInicio!) : '…';
    final fin = _fechaFin != null ? f.format(_fechaFin!) : '…';
    return 'Del $ini al $fin';
  }

  void _exportarPdf() {
    abrirVistaPreviaPdf(
      context,
      titulo: 'Dashboard General',
      nombreArchivo: 'dashboard_general.pdf',
      generar: () => DashboardPdfService.generar(
        totalClientes: _totalClientes,
        totalCobros: _totalCobros,
        totalPrestado: _totalPrestado,
        totalPagado: _totalPagado,
        totalPendiente: _totalPendiente,
        totalInteres: _totalInteres,
        totalMoras: _totalMoras,
        cantidadMoras: _cantidadMoras,
        filtroFechas: _filtroTexto,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final escritorio = esEscritorio(context);
    final columnas = escritorio ? 4 : 2;

    return CeScaffold(
      maxWidth: 1200,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Dashboard General'),
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
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: CEColors.danger, size: 40),
                        const SizedBox(height: 12),
                        const Text('No se pudo cargar el dashboard',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, color: CEColors.textSecondary)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _cargar,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    CeCard(
                      child: FiltroFechaRango(
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
                    ),
                    const CeSectionLabel('Cartera'),
                    _grid(columnas, [
                      CeStatItem(
                          icono: Icons.people_outline, valor: '$_totalClientes', etiqueta: 'Clientes'),
                      CeStatItem(
                          icono: Icons.trending_up,
                          valor: '$_prestamosActivos',
                          etiqueta: 'Préstamos Activos',
                          color: CEColors.accent),
                      CeStatItem(
                          icono: Icons.warning_amber_outlined,
                          valor: '$_prestamosMora',
                          etiqueta: 'En Mora',
                          color: CEColors.danger),
                      CeStatItem(
                          icono: Icons.check_circle_outline,
                          valor: '$_prestamosSaldados',
                          etiqueta: 'Saldados',
                          color: CEColors.success),
                    ]),
                    const CeSectionLabel('Financiero'),
                    _grid(columnas, [
                      CeStatItem(
                          icono: Icons.account_balance_outlined,
                          valor: formatearLempiras(_totalPrestado),
                          etiqueta: 'Prestado'),
                      CeStatItem(
                          icono: Icons.savings_outlined,
                          valor: formatearLempiras(_totalPagado),
                          etiqueta: 'Pagado',
                          color: CEColors.success),
                      CeStatItem(
                          icono: Icons.account_balance_wallet_outlined,
                          valor: formatearLempiras(_totalPendiente),
                          etiqueta: 'Pendiente',
                          color: CEColors.danger),
                      CeStatItem(
                          icono: Icons.percent_outlined,
                          valor: formatearLempiras(_totalInteres),
                          etiqueta: 'Interés',
                          color: CEColors.warning),
                    ]),
                    const CeSectionLabel('Indicadores clave'),
                    _grid(columnas, [
                      CeStatItem(
                          icono: Icons.speed_outlined,
                          valor: '${_tasaCobro.toStringAsFixed(1)}%',
                          etiqueta: 'Tasa de Cobro',
                          color: CEColors.success),
                      CeStatItem(
                          icono: Icons.error_outline,
                          valor: '${_carteraEnMoraPct.toStringAsFixed(1)}%',
                          etiqueta: 'Cartera en Mora',
                          color: CEColors.danger),
                      CeStatItem(
                          icono: Icons.request_quote_outlined,
                          valor: formatearLempiras(_prestamoPromedio),
                          etiqueta: 'Préstamo Promedio',
                          color: CEColors.accent),
                      CeStatItem(
                          icono: Icons.show_chart,
                          valor: '${_rentabilidad.toStringAsFixed(1)}%',
                          etiqueta: 'Rentabilidad',
                          color: CEColors.warning),
                    ]),
                    const CeSectionLabel('Cobros del período'),
                    _grid(columnas, [
                      CeStatItem(
                          icono: Icons.payments_outlined, valor: '$_totalCobros', etiqueta: 'Cobros'),
                      CeStatItem(
                          icono: Icons.report_gmailerrorred_outlined,
                          valor: formatearLempiras(_totalMoras),
                          etiqueta: 'Moras Cobradas',
                          color: CEColors.danger),
                      CeStatItem(
                          icono: Icons.numbers_outlined,
                          valor: '$_cantidadMoras',
                          etiqueta: 'Cant. Moras'),
                    ]),
                    const SizedBox(height: 20),
                    if (escritorio)
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _panelGrafico('Distribución Financiera', _graficoDistribucion())),
                            const SizedBox(width: 16),
                            Expanded(child: _panelGrafico('Cobros por Cobrador', _graficoPorCobrador())),
                          ],
                        ),
                      )
                    else ...[
                      _panelGrafico('Distribución Financiera', _graficoDistribucion()),
                      const SizedBox(height: 20),
                      _panelGrafico('Cobros por Cobrador', _graficoPorCobrador()),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
    );
  }

  Widget _grid(int columnas, List<CeStatItem> cards) {
    return CeStatGrid(
      mobileCrossAxisCount: columnas,
      mobileChildAspectRatio: 1.2,
      items: cards,
    );
  }

  Widget _panelGrafico(String titulo, Widget grafico) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 10),
        CeCard(child: grafico),
      ],
    );
  }

  Widget _graficoDistribucion() {
    final datos = <(String, double, Color)>[
      ('Pagado', _totalPagado, CEColors.success),
      ('Pendiente', _totalPendiente.clamp(0, double.infinity), CEColors.danger),
      ('Interés', _totalInteres, CEColors.warning),
    ].where((d) => d.$2 > 0).toList();

    if (datos.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('Sin datos para mostrar')),
      );
    }

    return SizedBox(
      height: 220,
      child: Row(
        children: [
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: datos
                    .map((d) => PieChartSectionData(
                          value: d.$2,
                          color: d.$3,
                          title: '',
                          radius: 60,
                        ))
                    .toList(),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: datos
                  .map((d) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(width: 10, height: 10, color: d.$3),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('${d.$1}: ${formatearLempiras(d.$2)}',
                                  style: const TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  // Barras horizontales tipo ranking en vez de un BarChart vertical: con
  // varios cobradores (o nombres largos) las etiquetas del eje inferior
  // se amontonaban/solapaban entre si. Cada fila es simplemente un
  // Row/nombre+barra+monto, asi que nunca colisiona sin importar
  // cuantos cobradores haya o que tan largo sea el nombre.
  Widget _graficoPorCobrador() {
    if (_porCobrador.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(child: Text('Sin cobros en este período')),
      );
    }

    final entradas = _porCobrador.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxValor = entradas.first.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entradas
          .map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 96,
                      child: Text(
                        e.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: maxValor > 0 ? e.value / maxValor : 0,
                          minHeight: 14,
                          backgroundColor: CEColors.border,
                          color: CEColors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 78,
                      child: Text(
                        formatearLempiras(e.value),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}
