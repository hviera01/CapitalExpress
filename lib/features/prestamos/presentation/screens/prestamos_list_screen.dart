import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/roles.dart';
import '../../../../core/models/prestamo_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/ce_card.dart';
import '../../../../core/widgets/ce_data_table_style.dart';
import '../../../../core/widgets/ce_scaffold.dart';
import '../../../../core/widgets/ce_stat_card.dart';
import '../../../../core/widgets/ce_web_nav.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/prestamos_busqueda_cache.dart';
import '../../providers/prestamos_provider.dart';
import 'crear_prestamo_screen.dart';
import 'editar_prestamo_screen.dart';
import 'prestamo_detalle_screen.dart';

const _estadosFiltro = ['Todos', 'Activo', 'Mora', 'Saldado'];

/// Igual que Ver Clientes: nada se carga solo con entrar a la pantalla.
/// Los 3 contadores de arriba salen de agregaciones (count en el
/// servidor), y la lista solo se trae al apretar "Buscar".
class PrestamosListScreen extends ConsumerStatefulWidget {
  const PrestamosListScreen({super.key});

  @override
  ConsumerState<PrestamosListScreen> createState() => _PrestamosListScreenState();
}

class _PrestamosListScreenState extends ConsumerState<PrestamosListScreen> {
  final _busquedaCtrl = TextEditingController();
  String _filtroEstado = 'Todos';
  bool _verEliminados = false;

  bool _cargandoStats = true;
  String? _errorStats;
  int _total = 0;
  int _activos = 0;
  int _saldados = 0;

  bool _buscando = false;
  bool _seBusco = false;
  List<PrestamoModel> _resultados = [];

  String? _cobradorUid;

  @override
  void initState() {
    super.initState();
    // Guardar/restaurar en cache es SOLO para escritorio Web -- ver
    // ClientesListScreen (mismo patron). En mobile/Windows cada
    // entrada arranca en blanco y vuelve a cargar todo, como siempre.
    if (esEscritorioWeb(context)) {
      final cache = ref.read(prestamosBusquedaCacheProvider);
      if (cache.seBusco) {
        _busquedaCtrl.text = cache.texto;
        _filtroEstado = cache.filtroEstado;
        _verEliminados = cache.verEliminados;
        _resultados = List.of(cache.resultados);
        _seBusco = true;
      }
      if (cache.tieneStats) {
        _total = cache.total;
        _activos = cache.activos;
        _saldados = cache.saldados;
        _cargandoStats = false;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarStats());
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  void _guardarCache() {
    if (!esEscritorioWeb(context)) return;
    final cache = ref.read(prestamosBusquedaCacheProvider);
    cache
      ..texto = _busquedaCtrl.text
      ..filtroEstado = _filtroEstado
      ..verEliminados = _verEliminados
      ..seBusco = _seBusco
      ..resultados = _resultados;
  }

  void _guardarStatsEnCache() {
    if (!esEscritorioWeb(context)) return;
    final cache = ref.read(prestamosBusquedaCacheProvider);
    cache
      ..tieneStats = true
      ..total = _total
      ..activos = _activos
      ..saldados = _saldados;
  }

  Future<void> _cargarStats() async {
    final usuario = ref.read(authProvider).usuario;
    final esAdmin = usuario?.rol == Roles.admin;
    _cobradorUid = esAdmin ? null : usuario?.uid;

    // Solo en escritorio Web: si ya hay datos, el refresco pasa
    // calladito, sin spinner. En mobile/Windows siempre se muestra el
    // spinner, como siempre.
    final primeraVez = !esEscritorioWeb(context) || _cargandoStats;
    if (primeraVez) {
      setState(() {
        _cargandoStats = true;
        _errorStats = null;
      });
    }
    final repo = ref.read(prestamoRepositoryProvider);
    try {
      final resultados = await Future.wait([
        repo.contar(cobradorUid: _cobradorUid),
        repo.contarPorEstado('activo', cobradorUid: _cobradorUid),
        repo.contarPorEstado('saldado', cobradorUid: _cobradorUid),
      ]);
      if (!mounted) return;
      setState(() {
        _total = resultados[0];
        _activos = resultados[1];
        _saldados = resultados[2];
        _cargandoStats = false;
      });
      _guardarStatsEnCache();
    } catch (e) {
      if (!mounted) return;
      if (primeraVez) {
        setState(() {
          _errorStats = '$e';
          _cargandoStats = false;
        });
      }
    }
  }

  Future<void> _buscar() async {
    setState(() => _buscando = true);
    final estado = _filtroEstado == 'Todos' ? null : _filtroEstado.toLowerCase();
    final resultados = await ref.read(prestamoRepositoryProvider).buscar(
          cobradorUid: _cobradorUid,
          estado: estado,
          incluirEliminados: _verEliminados,
          texto: _busquedaCtrl.text,
        );
    if (!mounted) return;
    setState(() {
      _resultados = resultados;
      _buscando = false;
      _seBusco = true;
    });
    _guardarCache();
  }

  Future<void> _eliminarTodos() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar todos'),
        content: const Text(
            'Se borrarán definitivamente todos los préstamos eliminados. Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar todos', style: TextStyle(color: CEColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      final usuario = ref.read(authProvider).usuario!;
      final borrados = await ref.read(prestamoRepositoryProvider).eliminarTodosLosEliminados(
          cobradorUid: _cobradorUid, usuarioUid: usuario.uid, usuarioNombre: usuario.nombre);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$borrados préstamo(s) borrados')));
        _buscar();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final esAdmin = ref.watch(authProvider).usuario?.rol == Roles.admin;
    final hayFiltros = _busquedaCtrl.text.isNotEmpty || _filtroEstado != 'Todos' || _verEliminados;

    return CeScaffold(
      maxWidth: 900,
      appBar: AppBar(
        leading: const BackButton(),
        backgroundColor: _verEliminados ? CEColors.danger : null,
        title: Text(_verEliminados ? 'Préstamos eliminados' : 'Préstamos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _cargarStats();
              if (_seBusco) _buscar();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            irAPantalla(context, ruta: '/prestamos/nuevo', pantalla: const CrearPrestamoScreen()),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo préstamo'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          if (_errorStats != null)
            CeCard(
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: CEColors.danger),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No se pudieron cargar las estadísticas: $_errorStats',
                      style: const TextStyle(fontSize: 12, color: CEColors.danger),
                    ),
                  ),
                  TextButton(onPressed: _cargarStats, child: const Text('Reintentar')),
                ],
              ),
            )
          else
            CeStatGrid(
              mobileCrossAxisCount: 3,
              mobileChildAspectRatio: 1.0,
              items: [
                CeStatItem(
                  icono: Icons.payments_outlined,
                  valor: _cargandoStats ? '…' : '$_total',
                  etiqueta: 'TOTAL',
                ),
                CeStatItem(
                  icono: Icons.check_circle_outline,
                  valor: _cargandoStats ? '…' : '$_activos',
                  etiqueta: 'ACTIVOS',
                  color: CEColors.success,
                ),
                CeStatItem(
                  icono: Icons.history_toggle_off,
                  valor: _cargandoStats ? '…' : '$_saldados',
                  etiqueta: 'SALDADOS',
                  color: CEColors.accent,
                ),
              ],
            ),
          const SizedBox(height: 16),
          CeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _busquedaCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar cliente o número...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Limpiar',
                      onPressed: () {
                        _busquedaCtrl.clear();
                        if (_seBusco) _buscar();
                      },
                    ),
                  ),
                  onSubmitted: (_) => _buscar(),
                ),
                if (esAdmin) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 18, color: CEColors.danger),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Ver eliminados', style: TextStyle(fontSize: 13))),
                      Switch(
                        value: _verEliminados,
                        activeThumbColor: CEColors.danger,
                        onChanged: (v) => setState(() => _verEliminados = v),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Estado de préstamo',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
                const SizedBox(height: 8),
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
                const SizedBox(height: 14),
                SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _buscando ? null : _buscar,
                    icon: _buscando
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.search),
                    label: const Text('Buscar'),
                  ),
                ),
                if (hayFiltros) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _busquedaCtrl.clear();
                        setState(() {
                          _filtroEstado = 'Todos';
                          _verEliminados = false;
                        });
                      },
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Limpiar filtros'),
                    ),
                  ),
                ],
                if (esAdmin && _verEliminados && _resultados.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: CEColors.danger,
                        side: const BorderSide(color: CEColors.danger),
                      ),
                      onPressed: _eliminarTodos,
                      icon: const Icon(Icons.delete_forever_outlined, size: 16),
                      label: const Text('Eliminar todos permanentemente'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (!_seBusco)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.search, size: 40, color: CEColors.textSecondary),
                    SizedBox(height: 12),
                    Text('Buscá para ver los préstamos',
                        style: TextStyle(color: CEColors.textSecondary)),
                  ],
                ),
              ),
            )
          else if (_resultados.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(child: Text('No hay préstamos')),
            )
          else if (esEscritorioWeb(context))
            _TablaPrestamos(
              prestamos: _resultados,
              eliminadoView: _verEliminados,
              esAdmin: esAdmin,
              onActualizado: (actualizado) {
                setState(() {
                  final i = _resultados.indexWhere((r) => r.prestamoId == actualizado.prestamoId);
                  if (i != -1) _resultados[i] = actualizado;
                });
                _guardarCache();
              },
              onEliminado: (p) {
                setState(() => _resultados.removeWhere((r) => r.prestamoId == p.prestamoId));
                _guardarCache();
                _cargarStats();
              },
            )
          else
            ..._resultados.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PrestamoCard(
                    prestamo: p,
                    eliminadoView: _verEliminados,
                    onActualizado: (actualizado) {
                      setState(() {
                        final i = _resultados.indexWhere((r) => r.prestamoId == actualizado.prestamoId);
                        if (i != -1) _resultados[i] = actualizado;
                      });
                      _guardarCache();
                    },
                    onEliminado: () {
                      setState(() => _resultados.removeWhere((r) => r.prestamoId == p.prestamoId));
                      _guardarCache();
                      _cargarStats();
                    },
                  ),
                )),
        ],
      ),
    );
  }
}

/// Version tabla de la lista de prestamos, solo para escritorio Web
/// (ver esEscritorioWeb) -- misma info y acciones que _PrestamoCard
/// pero usando el ancho completo de la pantalla.
class _TablaPrestamos extends ConsumerWidget {
  final List<PrestamoModel> prestamos;
  final bool eliminadoView;
  final bool esAdmin;
  final ValueChanged<PrestamoModel> onActualizado;
  final ValueChanged<PrestamoModel> onEliminado;

  const _TablaPrestamos({
    required this.prestamos,
    required this.eliminadoView,
    required this.esAdmin,
    required this.onActualizado,
    required this.onEliminado,
  });

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'saldado':
        return CEColors.success;
      case 'mora':
        return CEColors.danger;
      default:
        return CEColors.accent;
    }
  }

  Future<void> _refrescar(WidgetRef ref, PrestamoModel p) async {
    final actualizado = await ref.read(prestamoRepositoryProvider).obtenerPorId(p.prestamoId);
    if (actualizado == null || actualizado.eliminado != eliminadoView) {
      onEliminado(p);
    } else {
      onActualizado(actualizado);
    }
  }

  Future<void> _verDetalle(BuildContext context, WidgetRef ref, PrestamoModel p) async {
    await irAPantalla(context,
        ruta: '/prestamos/${p.prestamoId}',
        extra: p,
        pantalla: PrestamoDetalleScreen(prestamoId: p.prestamoId, prestamoInicial: p));
    await _refrescar(ref, p);
  }

  Future<void> _editar(BuildContext context, WidgetRef ref, PrestamoModel p) async {
    await irAPantalla(context,
        ruta: '/prestamos/${p.prestamoId}/editar',
        extra: p,
        pantalla: EditarPrestamoScreen(prestamoId: p.prestamoId, prestamoInicial: p));
    await _refrescar(ref, p);
  }

  Future<void> _eliminarORestaurar(BuildContext context, WidgetRef ref, PrestamoModel p) async {
    final repo = ref.read(prestamoRepositoryProvider);
    if (eliminadoView) {
      await repo.restaurar(p.prestamoId);
    } else {
      final usuario = ref.read(authProvider).usuario!;
      await repo.marcarEliminado(p.prestamoId,
          eliminadoPor: usuario.nombre,
          usuarioUid: usuario.uid,
          descripcionPrestamo: 'N° ${p.numeroPrestamo} - ${p.cliente}');
    }
    onEliminado(p);
  }

  Future<void> _eliminarPermanente(BuildContext context, WidgetRef ref, PrestamoModel p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar permanentemente'),
        content: Text(
            '¿Borrar definitivamente el préstamo de ${p.cliente}? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: CEColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      final usuario = ref.read(authProvider).usuario!;
      await ref.read(prestamoRepositoryProvider).eliminarPermanente(p.prestamoId,
          usuarioUid: usuario.uid,
          usuarioNombre: usuario.nombre,
          descripcionPrestamo: 'N° ${p.numeroPrestamo} - ${p.cliente}');
      onEliminado(p);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CeDataTableCard(
      columns: const [
        DataColumn(label: Text('Cliente')),
        DataColumn(label: Text('N°')),
        DataColumn(label: Text('Saldo'), numeric: true),
        DataColumn(label: Text('Estado')),
        DataColumn(label: Text('Cuotas')),
        DataColumn(label: Text('Cobrador')),
        DataColumn(label: Text('')),
      ],
      rows: prestamos.map((p) {
            return DataRow(
              onSelectChanged: (_) => _verDetalle(context, ref, p),
              cells: [
                DataCell(Text(p.cliente, style: const TextStyle(fontWeight: FontWeight.w600))),
                DataCell(Text('#${p.numeroPrestamo}')),
                DataCell(Text(formatearLempiras(p.saldo),
                    style: const TextStyle(fontWeight: FontWeight.w700, color: CEColors.accent))),
                DataCell(ceTableBadge(p.estado.toUpperCase(), _colorEstado(p.estado))),
                DataCell(Text('${p.cuotas}')),
                DataCell(Text(p.cobrador.isEmpty ? 'Sin asignar' : p.cobrador)),
                DataCell(PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18, color: CEColors.textSecondary),
                  onSelected: (accion) {
                    switch (accion) {
                      case 'ver':
                        _verDetalle(context, ref, p);
                        break;
                      case 'editar':
                        _editar(context, ref, p);
                        break;
                      case 'eliminar_restaurar':
                        _eliminarORestaurar(context, ref, p);
                        break;
                      case 'eliminar_permanente':
                        _eliminarPermanente(context, ref, p);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'ver',
                      child: ListTile(
                        leading: Icon(Icons.visibility_outlined),
                        title: Text('Ver detalle'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    if (!eliminadoView)
                      const PopupMenuItem(
                        value: 'editar',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Editar'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    if (esAdmin)
                      PopupMenuItem(
                        value: 'eliminar_restaurar',
                        child: ListTile(
                          leading: Icon(
                              eliminadoView ? Icons.restore_outlined : Icons.delete_outline,
                              color: eliminadoView ? CEColors.success : CEColors.danger),
                          title: Text(eliminadoView ? 'Restaurar' : 'Eliminar'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    if (eliminadoView)
                      const PopupMenuItem(
                        value: 'eliminar_permanente',
                        child: ListTile(
                          leading: Icon(Icons.delete_forever_outlined, color: CEColors.danger),
                          title: Text('Eliminar permanentemente'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                  ],
                )),
              ],
            );
          }).toList(),
    );
  }
}

class _PrestamoCard extends ConsumerWidget {
  final PrestamoModel prestamo;
  final bool eliminadoView;
  final ValueChanged<PrestamoModel> onActualizado;
  final VoidCallback onEliminado;

  const _PrestamoCard({
    required this.prestamo,
    required this.eliminadoView,
    required this.onActualizado,
    required this.onEliminado,
  });

  Future<void> _editar(BuildContext context, WidgetRef ref) async {
    await irAPantalla(context,
        ruta: '/prestamos/${prestamo.prestamoId}/editar',
        extra: prestamo,
        pantalla: EditarPrestamoScreen(prestamoId: prestamo.prestamoId, prestamoInicial: prestamo));
    // Al volver de editar, se trae el prestamo actualizado -- antes la
    // card se quedaba mostrando los datos viejos hasta repetir la
    // busqueda a mano.
    await _refrescar(ref);
  }

  /// Detalle del Prestamo tambien permite eliminar/restaurar/editar --
  /// al volver aca se refresca esta card (o se quita de la lista si ya
  /// no corresponde a la vista actual) en vez de dejarla con datos
  /// viejos.
  Future<void> _verDetalle(BuildContext context, WidgetRef ref) async {
    await irAPantalla(context,
        ruta: '/prestamos/${prestamo.prestamoId}',
        extra: prestamo,
        pantalla: PrestamoDetalleScreen(prestamoId: prestamo.prestamoId, prestamoInicial: prestamo));
    await _refrescar(ref);
  }

  Future<void> _refrescar(WidgetRef ref) async {
    final actualizado = await ref.read(prestamoRepositoryProvider).obtenerPorId(prestamo.prestamoId);
    if (actualizado == null || actualizado.eliminado != eliminadoView) {
      onEliminado();
    } else {
      onActualizado(actualizado);
    }
  }

  Color _colorEstado() {
    switch (prestamo.estado) {
      case 'saldado':
        return CEColors.success;
      case 'mora':
        return CEColors.danger;
      default:
        return CEColors.accent;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authProvider).usuario;
    final esAdmin = usuario?.rol == Roles.admin;

    return CeCard(
      padding: EdgeInsets.zero,
      onTap: () => _verDetalle(context, ref),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (eliminadoView)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: const BoxDecoration(
                color: CEColors.danger,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: const Center(
                child: Text('ELIMINADO',
                    style: TextStyle(
                        color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(prestamo.cliente,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: CEColors.surface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('#${prestamo.numeroPrestamo}',
                          style: const TextStyle(fontSize: 10, color: CEColors.textSecondary)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(formatearLempiras(prestamo.saldo),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 20, color: CEColors.accent)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _colorEstado().withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        prestamo.estado.toUpperCase(),
                        style: TextStyle(
                            fontSize: 11, color: _colorEstado(), fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    _mini(formatearLempiras(prestamo.cuota), 'Cuota'),
                    _mini('${prestamo.cuotas}', 'Cuotas'),
                    _mini(prestamo.plazo, 'Plazo'),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 14, color: CEColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        prestamo.cobrador.isEmpty ? 'Sin asignar' : prestamo.cobrador,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: CEColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _verDetalle(context, ref),
                        child: const Text('Ver'),
                      ),
                    ),
                    if (!eliminadoView) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _editar(context, ref),
                          child: const Text('Editar'),
                        ),
                      ),
                    ],
                    if (esAdmin) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: eliminadoView ? CEColors.success : CEColors.danger,
                            side: BorderSide(
                              color: eliminadoView ? CEColors.success : CEColors.danger,
                            ),
                          ),
                          onPressed: () async {
                            final repo = ref.read(prestamoRepositoryProvider);
                            if (eliminadoView) {
                              await repo.restaurar(prestamo.prestamoId);
                            } else {
                              final usuario = ref.read(authProvider).usuario!;
                              await repo.marcarEliminado(prestamo.prestamoId,
                                  eliminadoPor: usuario.nombre,
                                  usuarioUid: usuario.uid,
                                  descripcionPrestamo:
                                      'N° ${prestamo.numeroPrestamo} - ${prestamo.cliente}');
                            }
                            onEliminado();
                          },
                          child: Text(eliminadoView ? 'Restaurar' : 'Eliminar'),
                        ),
                      ),
                    ],
                  ],
                ),
                if (eliminadoView) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: CEColors.danger),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Eliminar permanentemente'),
                            content: Text(
                                '¿Borrar definitivamente el préstamo de ${prestamo.cliente}? Esta acción no se puede deshacer.'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancelar')),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Eliminar',
                                    style: TextStyle(color: CEColors.danger)),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          final usuario = ref.read(authProvider).usuario!;
                          await ref.read(prestamoRepositoryProvider).eliminarPermanente(
                              prestamo.prestamoId,
                              usuarioUid: usuario.uid,
                              usuarioNombre: usuario.nombre,
                              descripcionPrestamo:
                                  'N° ${prestamo.numeroPrestamo} - ${prestamo.cliente}');
                          onEliminado();
                        }
                      },
                      icon: const Icon(Icons.delete_forever_outlined, size: 16),
                      label: const Text('Eliminar permanentemente'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mini(String valor, String etiqueta) {
    return Expanded(
      child: Column(
        children: [
          Text(valor, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 2),
          Text(etiqueta, style: const TextStyle(fontSize: 10, color: CEColors.textSecondary)),
        ],
      ),
    );
  }
}
