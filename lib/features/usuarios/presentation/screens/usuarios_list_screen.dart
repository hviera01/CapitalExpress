import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/usuario_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/normalizar_texto.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/ce_card.dart';
import '../../../../core/widgets/ce_data_table_style.dart';
import '../../../../core/widgets/ce_scaffold.dart';
import '../../../../core/widgets/ce_stat_card.dart';
import '../../../../core/widgets/imagen_red_network.dart';
import '../../../prestamos/providers/prestamos_provider.dart';
import '../../providers/usuarios_cache.dart';
import '../../providers/usuarios_provider.dart';

const _rolesFiltro = ['todos', 'admin', 'cobrador'];
const _estadosFiltro = ['todos', 'activo', 'inactivo'];

/// Ver Usuarios (staff interno) -- coleccion chica, se carga completa de
/// una sola vez, igual que UsuariosVista.kt en el sistema viejo.
class UsuariosListScreen extends ConsumerStatefulWidget {
  const UsuariosListScreen({super.key});

  @override
  ConsumerState<UsuariosListScreen> createState() => _UsuariosListScreenState();
}

class _UsuariosListScreenState extends ConsumerState<UsuariosListScreen> {
  final _busquedaCtrl = TextEditingController();
  String _filtroRol = 'todos';
  String _filtroEstado = 'todos';

  bool _cargando = true;
  String? _error;
  List<UsuarioModel> _usuarios = [];
  final Map<String, int> _prestamosAsignados = {};

  @override
  void initState() {
    super.initState();
    // Si ya se habia cargado antes, se muestra de una en vez de
    // arrancar en blanco -- ver UsuariosCache. Se sigue refrescando
    // abajo, pero calladito (sin tapar la lista con el spinner).
    final cache = ref.read(usuariosCacheProvider);
    if (cache.tieneDatos) {
      _usuarios = List.of(cache.usuarios);
      _prestamosAsignados.addAll(cache.prestamosAsignados);
      _cargando = false;
    }
    _cargar();
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final primeraVez = _usuarios.isEmpty;
    if (primeraVez) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }
    try {
      final usuarios = await ref.read(usuarioRepositoryProvider).obtenerTodos();
      if (!mounted) return;
      setState(() {
        _usuarios = usuarios;
        _cargando = false;
      });

      final prestamoRepo = ref.read(prestamoRepositoryProvider);
      final cobradores = usuarios.where((u) => u.rol == 'cobrador').toList();
      final conteos = await Future.wait(
        cobradores.map((u) => prestamoRepo.contar(cobradorUid: u.uid)),
      );
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < cobradores.length; i++) {
          _prestamosAsignados[cobradores[i].uid] = conteos[i];
        }
      });
      final cache = ref.read(usuariosCacheProvider);
      cache
        ..tieneDatos = true
        ..usuarios = usuarios
        ..prestamosAsignados = _prestamosAsignados;
    } catch (e) {
      if (!mounted) return;
      if (primeraVez) {
        setState(() {
          _error = '$e';
          _cargando = false;
        });
      }
    }
  }

  Future<void> _cambiarEstado(UsuarioModel u, String nuevoEstado) async {
    final accion = nuevoEstado == 'inactivo' ? 'Inactivar' : 'Reactivar';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿$accion usuario?'),
        content: Text(nuevoEstado == 'inactivo'
            ? '¿Deseas marcar a ${u.nombre} como inactivo? Esta acción se puede revertir.'
            : '¿Deseas reactivar a ${u.nombre}? Volverá a estar activo en el sistema.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(accion,
                style: TextStyle(
                    color: nuevoEstado == 'inactivo' ? CEColors.danger : CEColors.success)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await ref.read(usuarioRepositoryProvider).actualizarEstado(u.uid, nuevoEstado);
    if (!mounted) return;
    setState(() {
      _usuarios = _usuarios
          .map((x) => x.uid == u.uid
              ? UsuarioModel(
                  uid: x.uid,
                  codigo: x.codigo,
                  password: x.password,
                  nombre: x.nombre,
                  rol: x.rol,
                  estado: nuevoEstado,
                  direccion: x.direccion,
                  identidad: x.identidad,
                  telefono: x.telefono,
                  fotoUrl: x.fotoUrl,
                )
              : x)
          .toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Usuario ${nuevoEstado == 'inactivo' ? 'inactivado' : 'reactivado'} correctamente')),
    );
  }

  List<UsuarioModel> get _filtrados {
    final q = normalizarTexto(_busquedaCtrl.text);
    return _usuarios.where((u) {
      if (_filtroRol != 'todos' && u.rol != _filtroRol) return false;
      if (_filtroEstado != 'todos' && u.estado != _filtroEstado) return false;
      if (q.isEmpty) return true;
      return normalizarTexto(u.nombre).contains(q) || u.codigo.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final total = _usuarios.length;
    final activos = _usuarios.where((u) => u.estado == 'activo').length;
    final inactivos = _usuarios.where((u) => u.estado == 'inactivo').length;

    return CeScaffold(
      maxWidth: 900,
      appBar: AppBar(leading: const BackButton(), title: const Text('Gestión de Usuarios')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/usuarios/nuevo'),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Nuevo usuario'),
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
                        Text('No se pudo cargar: $_error', textAlign: TextAlign.center),
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
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    CeStatGrid(
                      mobileCrossAxisCount: 3,
                      mobileChildAspectRatio: 1.1,
                      items: [
                        CeStatItem(icono: Icons.people_outline, valor: '$total', etiqueta: 'Total'),
                        CeStatItem(
                            icono: Icons.check_circle_outline,
                            valor: '$activos',
                            etiqueta: 'Activos',
                            color: CEColors.success),
                        CeStatItem(
                            icono: Icons.cancel_outlined,
                            valor: '$inactivos',
                            etiqueta: 'Inactivos',
                            color: CEColors.danger),
                      ],
                    ),
                    const SizedBox(height: 16),
                    CeCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _busquedaCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Nombre o código...',
                              prefixIcon: Icon(Icons.search),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          const Text('Rol', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: _rolesFiltro
                                .map((r) => ChoiceChip(
                                      label: Text(r),
                                      selected: _filtroRol == r,
                                      onSelected: (_) => setState(() => _filtroRol = r),
                                    ))
                                .toList(),
                          ),
                          const SizedBox(height: 12),
                          const Text('Estado', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: _estadosFiltro
                                .map((e) => ChoiceChip(
                                      label: Text(e),
                                      selected: _filtroEstado == e,
                                      onSelected: (_) => setState(() => _filtroEstado = e),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_filtrados.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Center(child: Text('No se encontraron usuarios')),
                      )
                    else if (esEscritorioWeb(context))
                      _TablaUsuarios(
                        usuarios: _filtrados,
                        prestamosAsignados: _prestamosAsignados,
                        onEditar: (u) async {
                          await context.push('/usuarios/${u.uid}/editar', extra: u);
                          _cargar();
                        },
                        onCambiarEstado: _cambiarEstado,
                      )
                    else
                      ..._filtrados.map((u) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _UsuarioTile(
                              usuario: u,
                              prestamosAsignados: _prestamosAsignados[u.uid] ?? 0,
                              onEditar: () async {
                                await context.push('/usuarios/${u.uid}/editar', extra: u);
                                // Al volver de editar, se recarga la lista --
                                // antes se quedaba mostrando los datos viejos
                                // hasta salir y volver a entrar.
                                _cargar();
                              },
                              onCambiarEstado: (nuevo) => _cambiarEstado(u, nuevo),
                            ),
                          )),
                  ],
                ),
    );
  }
}

/// Version tabla de la lista de usuarios, solo para escritorio Web (ver
/// esEscritorioWeb).
class _TablaUsuarios extends StatelessWidget {
  final List<UsuarioModel> usuarios;
  final Map<String, int> prestamosAsignados;
  final ValueChanged<UsuarioModel> onEditar;
  final void Function(UsuarioModel, String) onCambiarEstado;

  const _TablaUsuarios({
    required this.usuarios,
    required this.prestamosAsignados,
    required this.onEditar,
    required this.onCambiarEstado,
  });

  @override
  Widget build(BuildContext context) {
    return CeDataTableCard(
      columns: const [
        DataColumn(label: Text('Nombre')),
        DataColumn(label: Text('Código')),
        DataColumn(label: Text('Rol')),
        DataColumn(label: Text('Teléfono')),
        DataColumn(label: Text('Préstamos asignados')),
        DataColumn(label: Text('Estado')),
        DataColumn(label: Text('')),
      ],
      rows: usuarios.map((u) {
            final activo = u.estado == 'activo';
            return DataRow(cells: [
              DataCell(Text(u.nombre, style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text(u.codigo)),
              DataCell(Text(u.rol.toUpperCase())),
              DataCell(Text(u.telefono.isEmpty ? '—' : u.telefono)),
              DataCell(Text(u.rol == 'cobrador' ? '${prestamosAsignados[u.uid] ?? 0}' : '—')),
              DataCell(ceTableBadge(
                  u.estado.toUpperCase(), activo ? CEColors.success : CEColors.danger)),
              DataCell(PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 18, color: CEColors.textSecondary),
                onSelected: (accion) {
                  if (accion == 'editar') {
                    onEditar(u);
                  } else {
                    onCambiarEstado(u, activo ? 'inactivo' : 'activo');
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'editar',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Editar'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'estado',
                    child: ListTile(
                      leading: Icon(activo ? Icons.cancel_outlined : Icons.refresh,
                          color: activo ? CEColors.danger : CEColors.success),
                      title: Text(activo ? 'Inactivar' : 'Reactivar'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              )),
            ]);
          }).toList(),
    );
  }
}

class _UsuarioTile extends StatelessWidget {
  final UsuarioModel usuario;
  final int prestamosAsignados;
  final VoidCallback onEditar;
  final ValueChanged<String> onCambiarEstado;

  const _UsuarioTile({
    required this.usuario,
    required this.prestamosAsignados,
    required this.onEditar,
    required this.onCambiarEstado,
  });

  @override
  Widget build(BuildContext context) {
    final activo = usuario.estado == 'activo';

    return CeCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: usuario.fotoUrl.isNotEmpty
                      ? ImagenRedNetwork(url: usuario.fotoUrl)
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
                    Text(usuario.nombre,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 3),
                    Text('${usuario.rol.toUpperCase()} · ${usuario.codigo}',
                        style: const TextStyle(fontSize: 12, color: CEColors.textSecondary)),
                    if (usuario.telefono.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(usuario.telefono,
                          style: const TextStyle(fontSize: 12, color: CEColors.textSecondary)),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: activo ? CEColors.success : CEColors.danger,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  usuario.estado.toUpperCase(),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ],
          ),
          if (usuario.rol == 'cobrador') ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: CEColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.assignment_outlined, size: 14, color: CEColors.accent),
                  const SizedBox(width: 6),
                  Text('Préstamos asignados: $prestamosAsignados',
                      style: const TextStyle(
                          fontSize: 12, color: CEColors.accent, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onEditar,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Editar'),
              ),
              const SizedBox(width: 6),
              if (activo)
                TextButton.icon(
                  onPressed: () => onCambiarEstado('inactivo'),
                  style: TextButton.styleFrom(foregroundColor: CEColors.danger),
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('Inactivar'),
                )
              else
                TextButton.icon(
                  onPressed: () => onCambiarEstado('activo'),
                  style: TextButton.styleFrom(foregroundColor: CEColors.success),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reactivar'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
