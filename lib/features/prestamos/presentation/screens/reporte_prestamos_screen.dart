import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/roles.dart';
import '../../../../core/models/prestamo_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/normalizar_texto.dart';
import '../../../../core/utils/prestamo_estado_utils.dart';
import '../../../../core/widgets/ce_card.dart';
import '../../../../core/widgets/ce_scaffold.dart';
import '../../../../core/widgets/ce_stat_card.dart';
import '../../../../core/widgets/pdf_preview_screen.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../data/reporte_prestamos_pdf_service.dart';
import '../../providers/prestamos_provider.dart';

const _estadosFiltro = ['Todos', 'activo', 'vencido', 'saldado'];
const _fechasFiltro = ['Todos', 'Hoy', 'Semana', 'Mes'];

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
  String _filtroFecha = 'Todos';

  @override
  void initState() {
    super.initState();
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
    setState(() => _cargando = true);
    final prestamos = await ref
        .read(prestamoRepositoryProvider)
        .obtenerTodos(cobradorUid: esAdmin ? null : usuario?.uid);
    if (!mounted) return;
    setState(() {
      _prestamos = prestamos;
      _cargando = false;
    });
  }

  bool _pasaFecha(PrestamoModel p) {
    if (_filtroFecha == 'Todos') return true;
    final fecha = p.fechaCreacion?.toDate();
    if (fecha == null) return false;
    final hoy = DateTime.now();
    switch (_filtroFecha) {
      case 'Hoy':
        return fecha.year == hoy.year && fecha.month == hoy.month && fecha.day == hoy.day;
      case 'Semana':
        return fecha.isAfter(hoy.subtract(const Duration(days: 7)));
      case 'Mes':
        return fecha.year == hoy.year && fecha.month == hoy.month;
      default:
        return true;
    }
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
        filtroTexto: 'Estado: $_filtroEstado  ·  Fecha: $_filtroFecha',
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
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _fechasFiltro
                            .map((e) => ChoiceChip(
                                  label: Text(e),
                                  selected: _filtroFecha == e,
                                  onSelected: (_) => setState(() => _filtroFecha = e),
                                ))
                            .toList(),
                      ),
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
                    CeStatCard(icono: Icons.list_alt_outlined, valor: '${filas.length}', etiqueta: 'Total'),
                    CeStatCard(
                        icono: Icons.trending_up,
                        valor: '$activos',
                        etiqueta: 'Activos',
                        color: CEColors.accent),
                    CeStatCard(
                        icono: Icons.warning_amber_outlined,
                        valor: '$vencidos',
                        etiqueta: 'Vencidos',
                        color: CEColors.danger),
                    CeStatCard(
                        icono: Icons.account_balance_outlined,
                        valor: formatearLempiras(montoPrestado),
                        etiqueta: 'Prestado'),
                    CeStatCard(
                        icono: Icons.savings_outlined,
                        valor: formatearLempiras(montoPagado),
                        etiqueta: 'Pagado',
                        color: CEColors.success),
                    CeStatCard(
                        icono: Icons.report_gmailerrorred_outlined,
                        valor: formatearLempiras(mora),
                        etiqueta: 'Mora',
                        color: CEColors.danger),
                    CeStatCard(
                        icono: Icons.account_balance_wallet_outlined,
                        valor: formatearLempiras(pendiente),
                        etiqueta: 'Pendiente (con mora)',
                        color: CEColors.danger),
                  ],
                ),
                const SizedBox(height: 16),
                if (filas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(child: Text('No hay préstamos con este filtro')),
                  )
                else
                  ...filas.map((p) {
                    final estado = estadoEfectivoPrestamo(p);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: CeCard(
                        onTap: () => context.push('/prestamos/${p.prestamoId}'),
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
