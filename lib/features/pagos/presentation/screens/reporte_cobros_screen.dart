import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/roles.dart';
import '../../../../core/models/pago_model.dart';
import '../../../../core/models/usuario_simple.dart';
import '../../../../core/services/cloud_functions_http.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/normalizar_texto.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/ce_card.dart';
import '../../../../core/widgets/ce_scaffold.dart';
import '../../../../core/widgets/ce_stat_card.dart';
import '../../../../core/widgets/filtro_fecha_rango.dart';
import '../../../../core/widgets/pdf_preview_screen.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../usuarios/providers/usuarios_provider.dart';
import '../../data/reporte_cobros_pdf_service.dart';
import '../../providers/pagos_provider.dart';
import '../../providers/reporte_cobros_cache.dart';
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
  bool _refrescando = false;
  bool _esAdmin = true;
  String? _cobradorUid;

  // Se incrementa en cada _cargar(): si el usuario cambia de fecha
  // varias veces seguido (tablet/señal lenta), las respuestas pueden
  // llegar DESORDENADAS -- sin esto, una consulta vieja que responde
  // tarde pisaba el resultado de la mas nueva y mostraba pagos de la
  // fecha equivocada sin ningun aviso.
  int _cargaId = 0;

  List<PagoModel> _pagos = [];
  List<UsuarioSimple> _cobradores = [];

  final _busquedaCtrl = TextEditingController();
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  String? _filtroCobradorUid;

  @override
  void initState() {
    super.initState();
    // Cache es SOLO para escritorio Web -- ver ClientesListScreen
    // (mismo patron). En mobile/Windows cada entrada arranca en
    // blanco y recarga todo (filtro de fechas incluido, siempre "hoy"
    // por defecto), como siempre.
    if (esEscritorioWeb(context)) {
      final cache = ref.read(reporteCobrosCacheProvider);
      if (cache.tieneDatos) {
        _fechaInicio = cache.fechaInicio;
        _fechaFin = cache.fechaFin;
        _filtroCobradorUid = cache.filtroCobradorUid;
        _pagos = List.of(cache.pagos);
        _cobradores = List.of(cache.cobradores);
        _cargando = false;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final usuario = ref.read(authProvider).usuario;
    _esAdmin = Roles.esAdminOEquivalente(usuario?.rol);
    _cobradorUid = _esAdmin ? null : usuario?.uid;
    if (_fechaInicio == null && _fechaFin == null) {
      final hoy = DateTime.now();
      _fechaInicio = DateTime(hoy.year, hoy.month, hoy.day);
      _fechaFin = hoy;
    }
    // Cobradores (solo admin) y pagos son independientes -- antes se
    // pedian en serie, ahora a la vez.
    await Future.wait([
      if (_esAdmin && _cobradores.isEmpty)
        ref.read(cobradoresCacheProvider.future).then((c) => _cobradores = c),
      _cargar(),
    ]);
  }

  Future<void> _cargar() async {
    final miId = ++_cargaId;
    final primeraVez = !esEscritorioWeb(context) || _pagos.isEmpty;
    // _refrescando se prende SIEMPRE que haya una consulta en vuelo,
    // incluso en el refresco "calladito" de escritorio Web -- antes,
    // si ya habia datos en pantalla, cambiar de fecha no mostraba
    // ningun indicio de que se estaba recargando (se veia la lista
    // vieja quieta, como si el buscador no hubiera hecho nada).
    setState(() {
      if (primeraVez) _cargando = true;
      _refrescando = true;
    });
    final pagos = await _obtenerPagos();
    if (!mounted || miId != _cargaId) return; // una consulta mas nueva ya esta en curso/aplicada
    setState(() {
      _pagos = pagos;
      _cargando = false;
      _refrescando = false;
    });
    if (esEscritorioWeb(context)) {
      final cache = ref.read(reporteCobrosCacheProvider);
      cache
        ..tieneDatos = true
        ..fechaInicio = _fechaInicio
        ..fechaFin = _fechaFin
        ..filtroCobradorUid = _filtroCobradorUid
        ..pagos = pagos
        ..cobradores = _cobradores;
    }
  }

  /// Trae los pagos del rango via la Cloud Function `obtenerHistorialPagos`
  /// (mismo patron que Cobros: agrupa la consulta DENTRO del centro de
  /// datos, un solo viaje largo en vez de que el celular le pegue
  /// directo a Firestore). Si falla, cae al camino de siempre.
  Future<List<PagoModel>> _obtenerPagos() async {
    final cobradorUid = _filtroCobradorUid ?? _cobradorUid;
    try {
      final usuarioUid = ref.read(authProvider).usuario?.uid;
      final datos = await llamarCloudFunction('obtenerHistorialPagos', {
        'usuarioUid': usuarioUid,
        'filtroCobradorUid': _filtroCobradorUid,
        'inicio': _fechaInicio?.millisecondsSinceEpoch,
        'fin': _fechaFin?.millisecondsSinceEpoch,
      });
      final pagos = <PagoModel>[];
      for (final p in (datos['pagos'] as List)) {
        try {
          final mapa = Map<String, dynamic>.from(p as Map);
          pagos.add(PagoModel.fromMap(mapa['id'] as String, mapa));
        } catch (_) {
          // documento con formato inesperado: se omite.
        }
      }
      pagos.sort((a, b) => (b.fechaPago?.compareTo(a.fechaPago ?? b.fechaPago!) ?? 0));
      return pagos;
    } catch (_) {
      return ref
          .read(pagoRepositoryProvider)
          .obtenerConRango(inicio: _fechaInicio, fin: _fechaFin, cobradorUid: cobradorUid);
    }
  }

  List<PagoModel> get _pagosFiltrados {
    final q = _busquedaCtrl.text;
    if (q.trim().isEmpty) return _pagos;
    return _pagos.where((p) => coincideBusqueda(p.clienteNombre, q)).toList();
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
        title: Text(_esAdmin ? 'Historial de Pagos' : 'Mis Pagos'),
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
                // Se ve SIEMPRE que haya una consulta en vuelo (incluso
                // el refresco calladito de escritorio Web) -- antes,
                // cambiar de fecha con datos ya en pantalla no daba
                // ningun indicio de que se estaba recargando.
                if (_refrescando)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                      child: LinearProgressIndicator(minHeight: 3),
                    ),
                  ),
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
                CeStatGrid(
                  mobileCrossAxisCount: 3,
                  mobileChildAspectRatio: 1.15,
                  items: [
                    CeStatItem(
                        icono: Icons.receipt_long_outlined,
                        valor: '${filas.length}',
                        etiqueta: 'Pagos'),
                    CeStatItem(
                        icono: Icons.savings_outlined,
                        valor: formatearLempiras(totalAbonos),
                        etiqueta: 'Abonos',
                        color: CEColors.success),
                    CeStatItem(
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
                else if (esEscritorioWeb(context))
                  TablaPagos(
                    pagos: filas,
                    puedeEliminar: _esAdmin,
                    onEliminado: (p) => setState(() => _pagos.removeWhere((x) => x.docId == p.docId)),
                  )
                else
                  ...filas.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: PagoTile(
                          pago: p,
                          puedeEliminar: _esAdmin,
                          onEliminado: () => setState(() => _pagos.removeWhere((x) => x.docId == p.docId)),
                        ),
                      )),
              ],
            ),
    );
  }
}
