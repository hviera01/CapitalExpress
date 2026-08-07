import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/roles.dart';
import '../../../../core/models/cliente_model.dart';
import '../../../../core/models/prestamo_model.dart';
import '../../../../core/models/usuario_simple.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/reporte_clientes_calculos.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/ce_card.dart';
import '../../../../core/widgets/ce_scaffold.dart';
import '../../../../core/widgets/pdf_preview_screen.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../usuarios/providers/usuarios_provider.dart';
import '../../data/reporte_clientes_pdf_service.dart';
import '../../providers/clientes_provider.dart';
import '../../../prestamos/providers/prestamos_provider.dart';

const _estadosFiltro = ['Todos', 'Activos', 'Saldados'];

class _FilaCliente {
  final ClienteModel cliente;
  final String estado;
  final TotalesCliente totales;
  final DateTime? proximoPago;

  const _FilaCliente({
    required this.cliente,
    required this.estado,
    required this.totales,
    required this.proximoPago,
  });
}

class ReporteClientesScreen extends ConsumerStatefulWidget {
  const ReporteClientesScreen({super.key});

  @override
  ConsumerState<ReporteClientesScreen> createState() => _ReporteClientesScreenState();
}

class _ReporteClientesScreenState extends ConsumerState<ReporteClientesScreen> {
  bool _cargando = true;
  List<ClienteModel> _clientes = [];
  Map<String, List<PrestamoModel>> _prestamosPorCliente = {};
  List<UsuarioSimple> _cobradores = [];
  Map<String, String> _nombresCobradores = {};

  String _filtroEstado = 'Todos';
  String? _filtroCobradorUid;

  bool _esAdmin = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  Future<void> _cargar() async {
    final usuario = ref.read(authProvider).usuario;
    _esAdmin = usuario?.rol == Roles.admin;
    final cobradorUid = _esAdmin ? null : usuario?.uid;

    setState(() => _cargando = true);

    final resultados = await Future.wait([
      ref.read(clienteRepositoryProvider).obtenerTodos(cobradorUid: cobradorUid),
      ref.read(prestamoRepositoryProvider).obtenerTodos(cobradorUid: cobradorUid),
      if (_esAdmin) ref.read(usuarioRepositoryProvider).obtenerCobradores(),
    ]);

    final clientes = resultados[0] as List<ClienteModel>;
    final prestamos = resultados[1] as List<PrestamoModel>;
    final cobradores = _esAdmin ? resultados[2] as List<UsuarioSimple> : <UsuarioSimple>[];

    final agrupados = <String, List<PrestamoModel>>{};
    for (final p in prestamos) {
      agrupados.putIfAbsent(p.clienteId, () => []).add(p);
    }

    if (!mounted) return;
    setState(() {
      _clientes = clientes;
      _prestamosPorCliente = agrupados;
      _cobradores = cobradores;
      _nombresCobradores = {for (final c in cobradores) c.uid: c.nombre};
      _cargando = false;
    });
  }

  List<_FilaCliente> get _filas {
    final filas = _clientes.map((c) {
      final prestamos = _prestamosPorCliente[c.id] ?? const <PrestamoModel>[];
      return _FilaCliente(
        cliente: c,
        estado: estadoEfectivoCliente(estadoCliente: c.estado, prestamos: prestamos),
        totales: totalesCliente(prestamos),
        proximoPago: proximoPagoCliente(prestamos),
      );
    }).toList();

    var filtradas = filas;
    if (_filtroEstado == 'Activos') {
      filtradas = filtradas.where((f) => f.estado == 'activo').toList();
    } else if (_filtroEstado == 'Saldados') {
      filtradas = filtradas.where((f) => f.estado == 'saldado').toList();
    }
    if (_filtroCobradorUid != null) {
      filtradas =
          filtradas.where((f) => f.cliente.cobradorAsignado == _filtroCobradorUid).toList();
    }
    filtradas.sort((a, b) => a.cliente.nombre.toLowerCase().compareTo(b.cliente.nombre.toLowerCase()));
    return filtradas;
  }

  String _nombreCobradorDe(ClienteModel c) {
    if (c.cobradorAsignado.isEmpty) return 'Sin asignar';
    return _nombresCobradores[c.cobradorAsignado] ?? c.cobradorAsignado;
  }

  void _exportarPdf() {
    final filas = _filas
        .map((f) => FilaReporteCliente(
              cliente: f.cliente.nombre,
              telefono: f.cliente.telefono,
              cobrador: _nombreCobradorDe(f.cliente),
              estado: f.estado,
              totales: f.totales,
              proximoPago: f.proximoPago,
            ))
        .toList();

    final cobradorTexto = _filtroCobradorUid == null
        ? 'Todos'
        : (_nombresCobradores[_filtroCobradorUid] ?? _filtroCobradorUid!);

    abrirVistaPreviaPdf(
      context,
      titulo: 'Reporte de Clientes',
      nombreArchivo: 'reporte_clientes.pdf',
      generar: () => ReporteClientesPdfService.generar(
        filas: filas,
        filtroEstadoTexto: _filtroEstado,
        filtroCobradorTexto: cobradorTexto,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final escritorio = esEscritorio(context);
    final filas = _cargando ? const <_FilaCliente>[] : _filas;

    final resumen = totalesCliente(
      filas.expand((f) => _prestamosPorCliente[f.cliente.id] ?? const <PrestamoModel>[]).toList(),
    );
    final activos = filas.where((f) => f.estado == 'activo').length;
    final saldados = filas.where((f) => f.estado == 'saldado').length;

    return CeScaffold(
      maxWidth: 1200,
      appBar: AppBar(
        title: const Text('Reporte de Clientes'),
        actions: [
          if (_esAdmin)
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Filtros', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _estadosFiltro
                            .map((e) => ChoiceChip(
                                  label: Text(e),
                                  selected: _filtroEstado == e,
                                  onSelected: (_) => setState(() => _filtroEstado = e),
                                ))
                            .toList(),
                      ),
                      if (_esAdmin && _cobradores.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String?>(
                          initialValue: _filtroCobradorUid,
                          decoration: const InputDecoration(labelText: 'Cobrador'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Todos los cobradores')),
                            ..._cobradores.map(
                                (c) => DropdownMenuItem(value: c.uid, child: Text(c.nombre))),
                          ],
                          onChanged: (v) => setState(() => _filtroCobradorUid = v),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: CEColors.primary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Resumen',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 24,
                        runSpacing: 14,
                        children: [
                          _statPdf('Clientes', '${filas.length}'),
                          _statPdf('Activos', '$activos'),
                          _statPdf('Saldados', '$saldados'),
                          _statPdf('Prestado', formatearLempiras(resumen.prestado)),
                          _statPdf('Abonado', formatearLempiras(resumen.abonado)),
                          _statPdf('Mora', formatearLempiras(resumen.mora)),
                          _statPdf('Pendiente (con mora)', formatearLempiras(resumen.pendiente)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('${filas.length} cliente(s)',
                    style: const TextStyle(fontSize: 12, color: CEColors.textSecondary)),
                const SizedBox(height: 8),
                if (filas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(child: Text('No hay clientes con este filtro')),
                  )
                else if (escritorio)
                  _TablaClientes(filas: filas, nombreCobradorDe: _nombreCobradorDe)
                else
                  ...filas.map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _CardCliente(fila: f, cobrador: _nombreCobradorDe(f.cliente)),
                      )),
              ],
            ),
    );
  }

  Widget _statPdf(String label, String valor) {
    return SizedBox(
      width: 110,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.6))),
          const SizedBox(height: 2),
          Text(valor,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
        ],
      ),
    );
  }
}

class _TablaClientes extends StatelessWidget {
  final List<_FilaCliente> filas;
  final String Function(ClienteModel) nombreCobradorDe;

  const _TablaClientes({required this.filas, required this.nombreCobradorDe});

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'saldado':
        return CEColors.success;
      case 'inactivo':
        return CEColors.textSecondary;
      default:
        return CEColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatoFecha = DateFormat('dd/MM/yyyy');

    return CeCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(CEColors.primary),
          headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
          columns: const [
            DataColumn(label: Text('Cliente')),
            DataColumn(label: Text('Teléfono')),
            DataColumn(label: Text('Cobrador')),
            DataColumn(label: Text('Estado')),
            DataColumn(label: Text('Prestado'), numeric: true),
            DataColumn(label: Text('Abonado'), numeric: true),
            DataColumn(label: Text('Pendiente'), numeric: true),
            DataColumn(label: Text('Próximo pago')),
          ],
          rows: filas
              .map((f) => DataRow(cells: [
                    DataCell(Text(f.cliente.nombre)),
                    DataCell(Text(f.cliente.telefono.isEmpty ? 'N/D' : f.cliente.telefono)),
                    DataCell(Text(nombreCobradorDe(f.cliente))),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _colorEstado(f.estado).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(f.estado,
                          style: TextStyle(color: _colorEstado(f.estado), fontWeight: FontWeight.w700, fontSize: 11)),
                    )),
                    DataCell(Text(formatearLempiras(f.totales.prestado))),
                    DataCell(Text(formatearLempiras(f.totales.abonado))),
                    DataCell(Text(formatearLempiras(f.totales.pendiente),
                        style: const TextStyle(color: CEColors.accent, fontWeight: FontWeight.w700))),
                    DataCell(Text(f.proximoPago == null ? '—' : formatoFecha.format(f.proximoPago!))),
                  ]))
              .toList(),
        ),
      ),
    );
  }
}

class _CardCliente extends StatelessWidget {
  final _FilaCliente fila;
  final String cobrador;

  const _CardCliente({required this.fila, required this.cobrador});

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'saldado':
        return CEColors.success;
      case 'inactivo':
        return CEColors.textSecondary;
      default:
        return CEColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatoFecha = DateFormat('dd/MM/yyyy');
    final c = fila.cliente;

    return CeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(c.nombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _colorEstado(fila.estado).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(fila.estado,
                    style: TextStyle(
                        color: _colorEstado(fila.estado), fontWeight: FontWeight.w700, fontSize: 11)),
              ),
            ],
          ),
          if (c.telefono.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(c.telefono, style: const TextStyle(fontSize: 12, color: CEColors.textSecondary)),
          ],
          const SizedBox(height: 4),
          Text('Cobrador: $cobrador',
              style: const TextStyle(fontSize: 12, color: CEColors.textSecondary)),
          const Divider(height: 20),
          Row(
            children: [
              _mini('Prestado', formatearLempiras(fila.totales.prestado)),
              _mini('Abonado', formatearLempiras(fila.totales.abonado)),
              _mini('Pendiente', formatearLempiras(fila.totales.pendiente), color: CEColors.accent),
            ],
          ),
          if (fila.proximoPago != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.event_outlined, size: 14, color: CEColors.textSecondary),
                const SizedBox(width: 6),
                Text('Próximo pago: ${formatoFecha.format(fila.proximoPago!)}',
                    style: const TextStyle(fontSize: 12, color: CEColors.textSecondary)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _mini(String label, String valor, {Color color = CEColors.textPrimary}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: CEColors.textSecondary)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(valor,
                maxLines: 1,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }
}
