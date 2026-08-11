import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/roles.dart';
import '../../../../core/models/cliente_model.dart';
import '../../../../core/models/prestamo_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/contacto_utils.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/reporte_clientes_calculos.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/ce_card.dart';
import '../../../../core/widgets/ce_scaffold.dart';
import '../../../../core/widgets/ce_stat_card.dart';
import '../../../../core/widgets/ce_data_table_style.dart';
import '../../../../core/widgets/ce_web_nav.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../prestamos/providers/prestamos_provider.dart';
import '../../../usuarios/providers/usuarios_provider.dart';
import '../../providers/clientes_busqueda_cache.dart';
import '../../providers/clientes_provider.dart';
import 'cliente_form_screen.dart';
import 'cliente_resumen_screen.dart';

const _estados = ['Todos', 'Activo', 'Inactivo'];

/// Valor especial para el filtro de asignacion: clientes sin cobrador
/// asignado (se muestran como "Administrador" en toda la pantalla).
const _sinAsignarSentinel = '__sin_asignar__';

/// A diferencia del resto de la app, esta pantalla NO mantiene un stream
/// abierto sobre toda la coleccion (puede haber miles de clientes): las
/// estadisticas de arriba salen de consultas de agregacion livianas
/// (count/sum, sin bajar documentos) y la lista solo se trae cuando el
/// usuario aprieta "Buscar".
class ClientesListScreen extends ConsumerStatefulWidget {
  const ClientesListScreen({super.key});

  @override
  ConsumerState<ClientesListScreen> createState() => _ClientesListScreenState();
}

class _ClientesListScreenState extends ConsumerState<ClientesListScreen> {
  final _busquedaCtrl = TextEditingController();
  String _filtroEstado = 'Todos';
  // null = "Todos"; _sinAsignarSentinel = clientes sin cobrador; o el
  // uid de un cobrador puntual. Solo admin/desarrollador lo usan (un
  // cobrador ya ve solo lo suyo).
  String? _filtroCobradorUid;

  bool _cargandoStats = true;
  String? _errorStats;
  int _total = 0;
  int _activos = 0;
  int _pagosTarde = 0;
  double _pendiente = 0;

  bool _buscando = false;
  bool _seBusco = false;
  List<ClienteModel> _resultados = [];
  final Map<String, bool> _tienePrestamoReal = {};
  Map<String, String> _nombresCobradores = {};

  String? _cobradorUid;
  bool _esAdmin = true;

  @override
  void initState() {
    super.initState();
    // Guardar/restaurar en cache es SOLO para escritorio Web (ver
    // esEscritorioWeb) -- ahi es donde se pidio que las pantallas ya
    // visitadas no se sientan lentas al volver. En mobile/Windows se
    // deja el comportamiento de siempre: cada entrada arranca en
    // blanco y vuelve a cargar todo.
    if (esEscritorioWeb(context)) {
      // Si ya se habia buscado antes (y solo se salio y volvio a
      // entrar a la pantalla), se restaura esa busqueda en vez de
      // arrancar en blanco -- ver ClientesBusquedaCache. Igual con
      // las estadisticas del encabezado: si ya las teniamos, se
      // muestran de una (sin el parpadeo de "..." al volver) y se
      // refrescan calladitas atras.
      final cache = ref.read(clientesBusquedaCacheProvider);
      if (cache.seBusco) {
        _busquedaCtrl.text = cache.texto;
        _filtroEstado = cache.filtroEstado;
        _resultados = List.of(cache.resultados);
        _tienePrestamoReal.addAll(cache.tienePrestamoReal);
        _seBusco = true;
      }
      if (cache.tieneStats) {
        _total = cache.total;
        _activos = cache.activos;
        _pagosTarde = cache.pagosTarde;
        _pendiente = cache.pendiente;
        _nombresCobradores = Map.of(cache.nombresCobradores);
        _cargandoStats = false;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarStats();
      _cargarNombresCobradores();
    });
  }

  void _guardarCache() {
    if (!esEscritorioWeb(context)) return;
    final cache = ref.read(clientesBusquedaCacheProvider);
    cache
      ..texto = _busquedaCtrl.text
      ..filtroEstado = _filtroEstado
      ..seBusco = _seBusco
      ..resultados = _resultados
      ..tienePrestamoReal = _tienePrestamoReal;
  }

  void _guardarStatsEnCache() {
    if (!esEscritorioWeb(context)) return;
    final cache = ref.read(clientesBusquedaCacheProvider);
    cache
      ..tieneStats = true
      ..total = _total
      ..activos = _activos
      ..pagosTarde = _pagosTarde
      ..pendiente = _pendiente
      ..nombresCobradores = _nombresCobradores;
  }

  /// Para poder mostrar el nombre real del cobrador asignado en cada
  /// card (antes no se mostraba en ningun lado, ni siquiera en Resumen
  /// del Cliente). Solo hace falta para admin -- un cobrador viendo
  /// "Mis Clientes" ya sabe que son los suyos.
  Future<void> _cargarNombresCobradores() async {
    final usuario = ref.read(authProvider).usuario;
    if (!Roles.esAdminOEquivalente(usuario?.rol)) return;
    try {
      final cobradores = await ref.read(cobradoresCacheProvider.future);
      if (!mounted) return;
      setState(() {
        _nombresCobradores = {for (final c in cobradores) c.uid: c.nombre};
      });
      _guardarStatsEnCache();
    } catch (_) {
      // No es critico: si falla, las cards simplemente no muestran el
      // nombre del cobrador (se resuelve "Sin asignar"/UID como antes).
    }
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarStats() async {
    final usuario = ref.read(authProvider).usuario;
    _esAdmin = Roles.esAdminOEquivalente(usuario?.rol);
    _cobradorUid = _esAdmin ? null : usuario?.uid;

    // Solo en escritorio Web: si ya hay datos (de cache o de una carga
    // anterior), el refresco pasa calladito, sin spinner ni "...". En
    // mobile/Windows siempre se muestra el spinner, como siempre.
    final primeraVez = !esEscritorioWeb(context) || _cargandoStats;
    if (primeraVez) {
      setState(() {
        _cargandoStats = true;
        _errorStats = null;
      });
    }
    final clienteRepo = ref.read(clienteRepositoryProvider);
    final prestamoRepo = ref.read(prestamoRepositoryProvider);

    try {
      final resultados = await Future.wait([
        clienteRepo.contar(cobradorUid: _cobradorUid),
        clienteRepo.contar(cobradorUid: _cobradorUid, estado: 'activo'),
        prestamoRepo.contarEnMora(cobradorUid: _cobradorUid),
        prestamoRepo.sumarSaldoPendiente(cobradorUid: _cobradorUid),
      ]);

      if (!mounted) return;
      setState(() {
        _total = resultados[0] as int;
        _activos = resultados[1] as int;
        _pagosTarde = resultados[2] as int;
        _pendiente = resultados[3] as double;
        _cargandoStats = false;
      });
      _guardarStatsEnCache();
    } catch (e) {
      if (!mounted) return;
      // Si el refresco silencioso falla pero ya habia numeros en
      // pantalla (de cache o de una carga anterior), se dejan como
      // estaban -- no tiene sentido tapar datos buenos con un error
      // de un refresco de fondo que nadie pidio.
      if (primeraVez) {
        setState(() {
          _errorStats = '$e';
          _cargandoStats = false;
        });
      }
    }
  }

  /// Corrige prestamos cuyo cobrador quedo desincronizado del cliente
  /// al que pertenecen (ver ClienteRepository.sincronizarAsignaciones)
  /// -- se trabaja SOLO con asignacion de cliente, esto pone al dia lo
  /// que quedo desfasado de antes (reasignaciones parciales viejas).
  Future<void> _sincronizarAsignaciones() async {
    final mensajero = ScaffoldMessenger.of(context);
    mensajero.showSnackBar(const SnackBar(content: Text('Sincronizando asignaciones...')));
    try {
      final corregidos = await ref.read(clienteRepositoryProvider).sincronizarAsignaciones();
      if (!mounted) return;
      mensajero.showSnackBar(SnackBar(
          content: Text(corregidos == 0
              ? 'Todo ya estaba sincronizado'
              : 'Se corrigieron $corregidos préstamo(s)')));
    } catch (e) {
      if (!mounted) return;
      mensajero.showSnackBar(SnackBar(content: Text('No se pudo sincronizar: $e')));
    }
  }

  Future<void> _buscar() async {
    setState(() => _buscando = true);
    final estado = switch (_filtroEstado) {
      'Activo' => 'activo',
      'Inactivo' => 'inactivo',
      _ => null,
    };
    // El filtro de asignacion (solo admin/desarrollador) es aparte del
    // alcance normal (_cobradorUid, que para ellos siempre es null):
    // si eligieron un cobrador puntual, se lo pasa a la consulta igual
    // que si fueran ese cobrador; si eligieron "Administrador" (sin
    // asignar), no hay forma de pedirselo a Firestore directo, se trae
    // todo el alcance y se filtra en memoria.
    final filtroCobrador = _filtroCobradorUid;
    final cobradorParaConsulta =
        (filtroCobrador != null && filtroCobrador != _sinAsignarSentinel)
            ? filtroCobrador
            : _cobradorUid;
    var resultados = await ref.read(clienteRepositoryProvider).buscar(
          cobradorUid: cobradorParaConsulta,
          estado: estado,
          texto: _busquedaCtrl.text,
        );
    if (filtroCobrador == _sinAsignarSentinel) {
      resultados = resultados.where((c) => c.cobradorAsignado.isEmpty).toList();
    }
    if (!mounted) return;
    setState(() {
      _resultados = resultados;
      _buscando = false;
      _seBusco = true;
    });
    _guardarCache();

    // El campo `tienePrestamo` del doc del cliente puede estar
    // desactualizado (ver PrestamoRepository.tienePrestamoActivo); se
    // verifica el real aparte, sin bloquear que la lista ya se muestre.
    final prestamoRepo = ref.read(prestamoRepositoryProvider);
    final verificaciones = await Future.wait(
      resultados.map((c) => prestamoRepo.tienePrestamoActivo(c.id)),
    );
    if (!mounted) return;
    setState(() {
      for (var i = 0; i < resultados.length; i++) {
        _tienePrestamoReal[resultados[i].id] = verificaciones[i];
      }
    });
    _guardarCache();
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(authProvider).usuario;
    final esAdmin = Roles.esAdminOEquivalente(usuario?.rol);

    return CeScaffold(
      maxWidth: 900,
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(esAdmin ? 'Ver Clientes' : 'Mis Clientes'),
        actions: [
          if (esAdmin)
            IconButton(
              icon: const Icon(Icons.sync_outlined),
              tooltip: 'Sincronizar asignaciones (préstamos con su cliente)',
              onPressed: _sincronizarAsignaciones,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            irAPantalla(context, ruta: '/clientes/nuevo', pantalla: const ClienteFormScreen()),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Nuevo cliente'),
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
              mobileCrossAxisCount: 2,
              mobileChildAspectRatio: 1.3,
              items: [
                CeStatItem(
                  icono: Icons.people_outline,
                  valor: _cargandoStats ? '…' : '$_total',
                  etiqueta: 'Total',
                ),
                CeStatItem(
                  icono: Icons.trending_up,
                  valor: _cargandoStats ? '…' : '$_activos',
                  etiqueta: 'Activos',
                  color: CEColors.success,
                ),
                CeStatItem(
                  icono: Icons.warning_amber_outlined,
                  valor: _cargandoStats ? '…' : '$_pagosTarde',
                  etiqueta: 'Pagos Tarde',
                  color: CEColors.danger,
                ),
                CeStatItem(
                  icono: Icons.account_balance_wallet_outlined,
                  valor: _cargandoStats ? '…' : formatearLempiras(_pendiente),
                  etiqueta: 'Pendiente',
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
                    hintText: 'Buscar por nombre, identidad o teléfono',
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
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _filtroEstado,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items:
                      _estados.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setState(() => _filtroEstado = v ?? 'Todos'),
                ),
                if (_esAdmin) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    initialValue: _filtroCobradorUid,
                    decoration: const InputDecoration(labelText: 'Asignación'),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Todos')),
                      const DropdownMenuItem<String?>(
                          value: _sinAsignarSentinel, child: Text('Administrador (sin asignar)')),
                      ..._nombresCobradores.entries.map(
                          (e) => DropdownMenuItem<String?>(value: e.key, child: Text(e.value))),
                    ],
                    onChanged: (v) => setState(() => _filtroCobradorUid = v),
                  ),
                ],
                const SizedBox(height: 12),
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
                    Text('Buscá para ver los clientes',
                        style: TextStyle(color: CEColors.textSecondary)),
                  ],
                ),
              ),
            )
          else ...[
            Text(
              'Mostrando ${_resultados.length} de $_total clientes',
              style: const TextStyle(fontSize: 12, color: CEColors.textSecondary),
            ),
            const SizedBox(height: 8),
            if (_resultados.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: Text('No se encontraron clientes')),
              )
            else if (esEscritorioWeb(context))
              _TablaClientes(
                clientes: _resultados,
                tienePrestamoDe: (c) => _tienePrestamoReal[c.id] ?? c.tienePrestamo,
                nombreCobradorDe: (c) =>
                    c.cobradorAsignado.isEmpty ? 'Administrador' : _nombresCobradores[c.cobradorAsignado],
                onEliminado: (c) {
                  setState(() => _resultados.removeWhere((r) => r.id == c.id));
                  _guardarCache();
                  _cargarStats();
                },
                onActualizado: (actualizado) {
                  setState(() {
                    final i = _resultados.indexWhere((r) => r.id == actualizado.id);
                    if (i != -1) _resultados[i] = actualizado;
                  });
                  _guardarCache();
                },
              )
            else
              ..._resultados.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ClienteTile(
                      cliente: c,
                      tienePrestamo: _tienePrestamoReal[c.id] ?? c.tienePrestamo,
                      nombreCobrador: c.cobradorAsignado.isEmpty
                          ? 'Administrador'
                          : _nombresCobradores[c.cobradorAsignado],
                      onEliminado: () {
                        setState(() => _resultados.removeWhere((r) => r.id == c.id));
                        _guardarCache();
                        _cargarStats();
                      },
                      onActualizado: (actualizado) {
                        setState(() {
                          final i = _resultados.indexWhere((r) => r.id == actualizado.id);
                          if (i != -1) _resultados[i] = actualizado;
                        });
                        _guardarCache();
                      },
                    ),
                  )),
          ],
        ],
      ),
    );
  }
}

/// Version tabla de la lista de clientes, solo para escritorio Web (ver
/// esEscritorioWeb) -- misma info que _ClienteTile pero usando el
/// ancho completo de la pantalla. En vez del acordeon con el resumen
/// de prestamos, tocar la fila abre Resumen del Cliente directamente
/// (ya trae ese mismo resumen).
class _TablaClientes extends ConsumerWidget {
  final List<ClienteModel> clientes;
  final bool Function(ClienteModel) tienePrestamoDe;
  final String? Function(ClienteModel) nombreCobradorDe;
  final ValueChanged<ClienteModel> onEliminado;
  final ValueChanged<ClienteModel> onActualizado;

  const _TablaClientes({
    required this.clientes,
    required this.tienePrestamoDe,
    required this.nombreCobradorDe,
    required this.onEliminado,
    required this.onActualizado,
  });

  Future<void> _abrirResumen(BuildContext context, WidgetRef ref, ClienteModel c) async {
    await irAPantalla(context,
        ruta: '/clientes/${c.id}',
        extra: c,
        pantalla: ClienteResumenScreen(clienteId: c.id, clienteInicial: c));
    final actualizado = await ref.read(clienteRepositoryProvider).obtenerPorId(c.id);
    if (actualizado != null) {
      onActualizado(actualizado);
    } else {
      onEliminado(c);
    }
  }

  Future<void> _editar(BuildContext context, WidgetRef ref, ClienteModel c) async {
    await irAPantalla(context,
        ruta: '/clientes/${c.id}/editar',
        extra: c,
        pantalla: ClienteFormScreen(clienteId: c.id, clienteInicial: c));
    final actualizado = await ref.read(clienteRepositoryProvider).obtenerPorId(c.id);
    if (actualizado != null) onActualizado(actualizado);
  }

  Future<void> _eliminar(BuildContext context, WidgetRef ref, ClienteModel c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar cliente'),
        content: Text('¿Eliminar a ${c.nombre}? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: CEColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final usuario = ref.read(authProvider).usuario!;
      await ref.read(clienteRepositoryProvider).eliminar(c.id,
          nombreCliente: c.nombre, usuarioUid: usuario.uid, usuarioNombre: usuario.nombre);
      onEliminado(c);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${c.nombre} fue eliminado')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CeDataTableCard(
      columns: const [
        DataColumn(label: Text('Cliente')),
        DataColumn(label: Text('Teléfono')),
        DataColumn(label: Text('Identidad')),
        DataColumn(label: Text('Cobrador')),
        DataColumn(label: Text('Préstamo')),
        DataColumn(label: Text('')),
      ],
      rows: clientes.map((c) {
            final nombreCobrador = nombreCobradorDe(c);
            return DataRow(
              onSelectChanged: (_) => _abrirResumen(context, ref, c),
              cells: [
                DataCell(Text(c.nombre, style: const TextStyle(fontWeight: FontWeight.w600))),
                DataCell(Text(c.telefono.isEmpty ? '—' : c.telefono)),
                DataCell(Text(c.identidad.isEmpty ? '—' : c.identidad)),
                DataCell(Text(nombreCobrador ?? c.cobradorAsignado)),
                DataCell(tienePrestamoDe(c)
                    ? ceTableBadge('Con préstamo', CEColors.accent)
                    : const Text('—')),
                DataCell(PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18, color: CEColors.textSecondary),
                  onSelected: (accion) {
                    switch (accion) {
                      case 'ver':
                        _abrirResumen(context, ref, c);
                        break;
                      case 'editar':
                        _editar(context, ref, c);
                        break;
                      case 'llamar':
                        llamarTelefono(c.telefono);
                        break;
                      case 'whatsapp':
                        abrirWhatsapp(c.telefono);
                        break;
                      case 'eliminar':
                        _eliminar(context, ref, c);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'ver',
                      child: ListTile(
                        leading: Icon(Icons.visibility_outlined),
                        title: Text('Ver resumen'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'editar',
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Editar'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    if (c.telefono.isNotEmpty) ...[
                      const PopupMenuItem(
                        value: 'llamar',
                        child: ListTile(
                          leading: Icon(Icons.call_outlined),
                          title: Text('Llamar'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'whatsapp',
                        child: ListTile(
                          leading: Icon(Icons.chat_outlined, color: Color(0xFF25D366)),
                          title: Text('WhatsApp'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                    const PopupMenuItem(
                      value: 'eliminar',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline, color: CEColors.danger),
                        title: Text('Eliminar'),
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

class _ClienteTile extends ConsumerStatefulWidget {
  final ClienteModel cliente;
  final bool tienePrestamo;
  final String? nombreCobrador;
  final VoidCallback onEliminado;
  final ValueChanged<ClienteModel> onActualizado;

  const _ClienteTile({
    required this.cliente,
    required this.tienePrestamo,
    required this.onEliminado,
    required this.onActualizado,
    this.nombreCobrador,
  });

  @override
  ConsumerState<_ClienteTile> createState() => _ClienteTileState();
}

class _ClienteTileState extends ConsumerState<_ClienteTile> {
  bool _expandido = false;
  bool _cargando = false;
  String? _error;
  List<PrestamoModel>? _prestamos;

  Future<void> _toggle() async {
    if (_cargando) return; // evita doble-tap mientras ya esta cargando
    if (!_expandido && _prestamos == null) {
      setState(() {
        _cargando = true;
        _error = null;
      });
      try {
        final prestamos =
            await ref.read(prestamoRepositoryProvider).obtenerPorCliente(widget.cliente.id);
        if (!mounted) return;
        setState(() {
          _prestamos = prestamos;
          _cargando = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = '$e';
          _cargando = false;
          _expandido = true; // se expande igual para mostrar el error + reintentar
        });
        return;
      }
    }
    setState(() => _expandido = !_expandido);
  }

  void _reintentar() {
    setState(() {
      _prestamos = null;
      _expandido = false;
    });
    _toggle();
  }

  Future<void> _accion(BuildContext context, String accion) async {
    final c = widget.cliente;
    switch (accion) {
      case 'editar':
        await irAPantalla(context,
            ruta: '/clientes/${c.id}/editar',
            extra: c,
            pantalla: ClienteFormScreen(clienteId: c.id, clienteInicial: c));
        // Al volver de editar, se trae el cliente actualizado -- antes
        // la fila se quedaba mostrando los datos viejos hasta que se
        // repetia la busqueda a mano.
        final actualizado = await ref.read(clienteRepositoryProvider).obtenerPorId(c.id);
        if (actualizado != null) widget.onActualizado(actualizado);
        break;
      case 'llamar':
        llamarTelefono(c.telefono);
        break;
      case 'whatsapp':
        abrirWhatsapp(c.telefono);
        break;
      case 'eliminar':
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Eliminar cliente'),
            content: Text('¿Eliminar a ${c.nombre}? Esta acción no se puede deshacer.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Eliminar', style: TextStyle(color: CEColors.danger)),
              ),
            ],
          ),
        );
        if (ok == true) {
          try {
            final usuario = ref.read(authProvider).usuario!;
            await ref.read(clienteRepositoryProvider).eliminar(c.id,
                nombreCliente: c.nombre, usuarioUid: usuario.uid, usuarioNombre: usuario.nombre);
            widget.onEliminado();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${c.nombre} fue eliminado')),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('No se pudo eliminar: $e')),
              );
            }
          }
        }
        break;
    }
  }

  /// Dentro de Resumen del Cliente se puede editar o eliminar el
  /// cliente -- al volver aca (con o sin cambios) se refresca esta
  /// fila para no quedar mostrando datos viejos o un cliente ya
  /// borrado.
  Future<void> _abrirResumen(BuildContext context) async {
    await irAPantalla(context,
        ruta: '/clientes/${widget.cliente.id}',
        extra: widget.cliente,
        pantalla: ClienteResumenScreen(clienteId: widget.cliente.id, clienteInicial: widget.cliente));
    final actualizado = await ref.read(clienteRepositoryProvider).obtenerPorId(widget.cliente.id);
    if (actualizado != null) {
      widget.onActualizado(actualizado);
    } else {
      widget.onEliminado();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.cliente;
    return CeCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            onTap: () => _abrirResumen(context),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.nombre,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 4),
                        if (c.telefono.isNotEmpty) _filaIcono(Icons.call_outlined, c.telefono),
                        if (c.nombreEmpresa.isNotEmpty)
                          _filaIcono(Icons.storefront_outlined, c.nombreEmpresa),
                        if (c.identidad.isNotEmpty)
                          _filaIcono(Icons.badge_outlined, c.identidad),
                        if (widget.nombreCobrador != null)
                          _filaIcono(Icons.person_pin_circle_outlined, widget.nombreCobrador!)
                        else if (c.cobradorAsignado.isEmpty)
                          _filaIcono(Icons.person_pin_circle_outlined, 'Sin cobrador asignado'),
                        if (widget.tienePrestamo) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: CEColors.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Con préstamo',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: CEColors.accent,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: CEColors.textSecondary),
                        onSelected: (accion) => _accion(context, accion),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'editar',
                            child: ListTile(
                              leading: Icon(Icons.edit_outlined),
                              title: Text('Editar'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'eliminar',
                            child: ListTile(
                              leading: Icon(Icons.delete_outline, color: CEColors.danger),
                              title: Text('Eliminar'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          if (c.telefono.isNotEmpty) ...[
                            const PopupMenuItem(
                              value: 'llamar',
                              child: ListTile(
                                leading: Icon(Icons.call_outlined),
                                title: Text('Llamar'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'whatsapp',
                              child: ListTile(
                                leading: Icon(Icons.chat_outlined, color: Color(0xFF25D366)),
                                title: Text('WhatsApp'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ],
                      ),
                      IconButton(
                        icon: Icon(_expandido ? Icons.expand_less : Icons.expand_more),
                        color: CEColors.textSecondary,
                        onPressed: _toggle,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_expandido) _panelResumen(),
        ],
      ),
    );
  }

  Widget _panelResumen() {
    if (_cargando) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          children: [
            const Icon(Icons.error_outline, size: 16, color: CEColors.danger),
            const SizedBox(width: 8),
            Expanded(
              child: Text('No se pudo cargar: $_error',
                  style: const TextStyle(fontSize: 12, color: CEColors.danger)),
            ),
            TextButton(onPressed: _reintentar, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    final prestamos = _prestamos ?? const [];
    if (prestamos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Text('Sin préstamos registrados',
            style: TextStyle(color: CEColors.textSecondary, fontSize: 12)),
      );
    }

    // Misma funcion que Reporte de Clientes / Resumen del Cliente, para
    // que "Pendiente" sea siempre el mismo numero (el campo `saldo`,
    // que ya incluye mora) sin importar desde donde se mire.
    final totales = totalesCliente(prestamos);
    var activos = 0, completados = 0;
    for (final p in prestamos) {
      if (p.estado == 'saldado') {
        completados++;
      } else {
        activos++;
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CEColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bar_chart, size: 16, color: CEColors.primary),
              SizedBox(width: 6),
              Text('Resumen de Préstamos',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _mini('${prestamos.length}', 'Total'),
              _mini('$activos', 'Activos'),
              _mini('$completados', 'Completados'),
            ],
          ),
          const Divider(height: 24),
          _filaMonto('Prestado', formatearLempiras(totales.prestado)),
          _filaMonto('Abonado', formatearLempiras(totales.abonado), color: CEColors.success),
          _filaMonto('Pendiente sin mora', formatearLempiras(totales.pendienteSinMora),
              color: CEColors.danger),
          if (totales.mora > 0) ...[
            _filaMonto('Mora', formatearLempiras(totales.mora), color: CEColors.danger),
            _filaMonto('Pendiente con mora', formatearLempiras(totales.pendiente),
                color: CEColors.danger),
          ],
        ],
      ),
    );
  }

  Widget _mini(String valor, String etiqueta) {
    return Expanded(
      child: Column(
        children: [
          Text(valor, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 2),
          Text(etiqueta, style: const TextStyle(fontSize: 10, color: CEColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _filaMonto(String label, String valor, {Color color = CEColors.textPrimary}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: CEColors.textSecondary)),
          Text(valor, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _filaIcono(IconData icono, String texto) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icono, size: 13, color: CEColors.textSecondary),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: CEColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
