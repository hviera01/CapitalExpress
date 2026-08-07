import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/widgets/ce_card.dart';
import '../../../../core/widgets/ce_scaffold.dart';
import '../../../../core/widgets/ce_stat_card.dart';
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

  int _totalClientes = 0;
  double _totalPrestado = 0;
  double _totalInteres = 0;
  double _totalPendiente = 0;
  int _totalCobros = 0;
  double _totalPagado = 0;
  double _totalMoras = 0;
  int _cantidadMoras = 0;
  Map<String, double> _porCobrador = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);

    final resultados = await Future.wait([
      ref.read(clienteRepositoryProvider).contar(),
      ref.read(prestamoRepositoryProvider).sumarMontoEInteres(),
      ref.read(pagoRepositoryProvider).obtenerConRango(inicio: _fechaInicio, fin: _fechaFin),
      ref.read(prestamoRepositoryProvider).sumarSaldoPendiente(),
    ]);

    final totalClientes = resultados[0] as int;
    final montoEInteres = resultados[1] as ({double monto, double interes});
    final pagos = resultados[2] as List<PagoModel>;
    final totalPendiente = resultados[3] as double;

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
      _cargando = false;
    });
  }

  String get _filtroTexto {
    final f = DateFormat('dd/MM/yyyy');
    if (_fechaInicio == null && _fechaFin == null) return 'Todo el período';
    final ini = _fechaInicio != null ? f.format(_fechaInicio!) : '…';
    final fin = _fechaFin != null ? f.format(_fechaFin!) : '…';
    return 'Del $ini al $fin';
  }

  Future<void> _elegirFecha({required bool esInicio}) async {
    final f = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now(),
    );
    if (f == null) return;
    setState(() {
      if (esInicio) {
        _fechaInicio = f;
      } else {
        _fechaFin = f;
      }
    });
    _cargar();
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
    final f = DateFormat('dd/MM/yyyy');

    return CeScaffold(
      maxWidth: 1100,
      appBar: AppBar(
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
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                CeCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _elegirFecha(esInicio: true),
                          icon: const Icon(Icons.calendar_today_outlined, size: 16),
                          label: Text(_fechaInicio == null ? 'Fecha Inicio' : f.format(_fechaInicio!)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _elegirFecha(esInicio: false),
                          icon: const Icon(Icons.calendar_today_outlined, size: 16),
                          label: Text(_fechaFin == null ? 'Fecha Fin' : f.format(_fechaFin!)),
                        ),
                      ),
                      if (_fechaInicio != null || _fechaFin != null)
                        IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Limpiar fechas',
                          onPressed: () {
                            setState(() {
                              _fechaInicio = null;
                              _fechaFin = null;
                            });
                            _cargar();
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.2,
                  children: [
                    CeStatCard(icono: Icons.people_outline, valor: '$_totalClientes', etiqueta: 'Clientes'),
                    CeStatCard(
                        icono: Icons.payments_outlined, valor: '$_totalCobros', etiqueta: 'Cobros'),
                    CeStatCard(
                        icono: Icons.account_balance_outlined,
                        valor: formatearLempiras(_totalPrestado),
                        etiqueta: 'Prestado'),
                    CeStatCard(
                        icono: Icons.savings_outlined,
                        valor: formatearLempiras(_totalPagado),
                        etiqueta: 'Pagado',
                        color: CEColors.success),
                    CeStatCard(
                        icono: Icons.warning_amber_outlined,
                        valor: formatearLempiras(_totalPendiente),
                        etiqueta: 'Pendiente',
                        color: CEColors.danger),
                    CeStatCard(
                        icono: Icons.percent_outlined,
                        valor: formatearLempiras(_totalInteres),
                        etiqueta: 'Interés',
                        color: CEColors.warning),
                    CeStatCard(
                        icono: Icons.report_gmailerrorred_outlined,
                        valor: formatearLempiras(_totalMoras),
                        etiqueta: 'Moras Cobradas',
                        color: CEColors.danger),
                    CeStatCard(
                        icono: Icons.numbers_outlined,
                        valor: '$_cantidadMoras',
                        etiqueta: 'Cant. Moras'),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Distribución Financiera',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 10),
                CeCard(child: _graficoDistribucion()),
                const SizedBox(height: 20),
                const Text('Cobros por Cobrador',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 10),
                CeCard(child: _graficoPorCobrador()),
                const SizedBox(height: 24),
              ],
            ),
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

  Widget _graficoPorCobrador() {
    if (_porCobrador.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('Sin cobros en este período')),
      );
    }

    final entradas = _porCobrador.entries.toList();
    final maxY = entradas.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 240,
      child: BarChart(
        BarChartData(
          maxY: maxY * 1.2,
          barGroups: [
            for (var i = 0; i < entradas.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(toY: entradas[i].value, color: CEColors.accent, width: 18),
              ]),
          ],
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= entradas.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(entradas[i].key,
                        style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis),
                  );
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}
