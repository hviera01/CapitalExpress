import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../../../../core/widgets/imagen_red_network.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../prestamos/providers/prestamos_provider.dart';
import '../../providers/clientes_provider.dart';

const _estados = ['Todos', 'Activo', 'Inactivo'];

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

  bool _cargandoStats = true;
  int _total = 0;
  int _activos = 0;
  int _pagosTarde = 0;
  double _pendiente = 0;

  bool _buscando = false;
  bool _seBusco = false;
  List<ClienteModel> _resultados = [];

  String? _cobradorUid;
  bool _esAdmin = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarStats());
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarStats() async {
    final usuario = ref.read(authProvider).usuario;
    _esAdmin = usuario?.rol == Roles.admin;
    _cobradorUid = _esAdmin ? null : usuario?.uid;

    setState(() => _cargandoStats = true);
    final clienteRepo = ref.read(clienteRepositoryProvider);
    final prestamoRepo = ref.read(prestamoRepositoryProvider);

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
  }

  Future<void> _buscar() async {
    setState(() => _buscando = true);
    final estado = switch (_filtroEstado) {
      'Activo' => 'activo',
      'Inactivo' => 'inactivo',
      _ => null,
    };
    final resultados = await ref.read(clienteRepositoryProvider).buscar(
          cobradorUid: _cobradorUid,
          estado: estado,
          texto: _busquedaCtrl.text,
        );
    if (!mounted) return;
    setState(() {
      _resultados = resultados;
      _buscando = false;
      _seBusco = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(authProvider).usuario;
    final esAdmin = usuario?.rol == Roles.admin;

    return CeScaffold(
      maxWidth: 900,
      appBar: AppBar(title: Text(esAdmin ? 'Ver Clientes' : 'Mis Clientes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/clientes/nuevo'),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Nuevo cliente'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          GridView.count(
            crossAxisCount: esEscritorio(context) ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.3,
            children: [
              CeStatCard(
                icono: Icons.people_outline,
                valor: _cargandoStats ? '…' : '$_total',
                etiqueta: 'Total',
              ),
              CeStatCard(
                icono: Icons.trending_up,
                valor: _cargandoStats ? '…' : '$_activos',
                etiqueta: 'Activos',
                color: CEColors.success,
              ),
              CeStatCard(
                icono: Icons.warning_amber_outlined,
                valor: _cargandoStats ? '…' : '$_pagosTarde',
                etiqueta: 'Pagos Tarde',
                color: CEColors.danger,
              ),
              CeStatCard(
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
            else
              ..._resultados.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ClienteTile(cliente: c),
                  )),
          ],
        ],
      ),
    );
  }
}

class _ClienteTile extends ConsumerStatefulWidget {
  final ClienteModel cliente;

  const _ClienteTile({required this.cliente});

  @override
  ConsumerState<_ClienteTile> createState() => _ClienteTileState();
}

class _ClienteTileState extends ConsumerState<_ClienteTile> {
  bool _expandido = false;
  bool _cargando = false;
  List<PrestamoModel>? _prestamos;

  Future<void> _toggle() async {
    if (!_expandido && _prestamos == null) {
      setState(() => _cargando = true);
      final prestamos =
          await ref.read(prestamoRepositoryProvider).obtenerPorCliente(widget.cliente.id);
      if (!mounted) return;
      setState(() {
        _prestamos = prestamos;
        _cargando = false;
      });
    }
    setState(() => _expandido = !_expandido);
  }

  Future<void> _accion(BuildContext context, String accion) async {
    final c = widget.cliente;
    switch (accion) {
      case 'editar':
        context.push('/clientes/${c.id}/editar');
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
          await ref.read(clienteRepositoryProvider).eliminar(c.id);
        }
        break;
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
            onTap: () => context.push('/clientes/${c.id}'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: c.fotoPersonaUrl.isNotEmpty
                          ? ImagenRedNetwork(url: c.fotoPersonaUrl)
                          : const ColoredBox(
                              color: CEColors.surface,
                              child: Icon(Icons.person_outline, color: CEColors.textSecondary),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
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
                        if (c.tienePrestamo) ...[
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
          if (totales.mora > 0)
            _filaMonto('Mora', formatearLempiras(totales.mora), color: CEColors.danger),
          _filaMonto('Pendiente', formatearLempiras(totales.pendiente), color: CEColors.danger),
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
          Text(texto, style: const TextStyle(fontSize: 12, color: CEColors.textSecondary)),
        ],
      ),
    );
  }
}
