import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/usuario_model.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/widgets/ce_scaffold.dart';
import '../../../../core/widgets/ce_section_card.dart';
import '../../../../core/widgets/selector_foto.dart';
import '../../providers/usuarios_provider.dart';

const _roles = ['admin', 'cobrador'];

/// Crear o editar un usuario del staff (admin/cobrador). Si [usuarioId]
/// es null es un usuario nuevo -- mismo criterio que ClienteFormScreen.
class UsuarioFormScreen extends ConsumerStatefulWidget {
  final String? usuarioId;
  final UsuarioModel? usuarioInicial;

  const UsuarioFormScreen({super.key, this.usuarioId, this.usuarioInicial});

  @override
  ConsumerState<UsuarioFormScreen> createState() => _UsuarioFormScreenState();
}

class _UsuarioFormScreenState extends ConsumerState<UsuarioFormScreen> {
  final _formKey = GlobalKey<FormState>();
  UsuarioModel? _usuarioOriginal;
  late bool _cargando = widget.usuarioInicial == null && widget.usuarioId != null;
  bool _guardando = false;
  bool _verPassword = false;

  final _nombreCtrl = TextEditingController();
  final _codigoCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _identidadCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();

  String _rol = 'admin';
  Uint8List? _fotoNueva;

  bool get _esNuevo => widget.usuarioId == null;

  @override
  void initState() {
    super.initState();
    if (widget.usuarioInicial != null) {
      // Ya lo teniamos en memoria (Ver Usuarios) -- sin viaje redondo a
      // Firestore antes de mostrar el formulario.
      _aplicarUsuario(widget.usuarioInicial!);
    } else if (widget.usuarioId != null) {
      _cargar();
    }
  }

  void _aplicarUsuario(UsuarioModel usuario) {
    _usuarioOriginal = usuario;
    _nombreCtrl.text = usuario.nombre;
    _codigoCtrl.text = usuario.codigo;
    _passwordCtrl.text = usuario.password;
    _telefonoCtrl.text = usuario.telefono;
    _identidadCtrl.text = usuario.identidad;
    _direccionCtrl.text = usuario.direccion;
    _rol = _roles.contains(usuario.rol) ? usuario.rol : 'admin';
  }

  Future<void> _cargar() async {
    final usuario = await ref.read(usuarioRepositoryProvider).obtenerPorId(widget.usuarioId!);
    if (usuario != null) _aplicarUsuario(usuario);
    if (mounted) setState(() => _cargando = false);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _codigoCtrl.dispose();
    _passwordCtrl.dispose();
    _telefonoCtrl.dispose();
    _identidadCtrl.dispose();
    _direccionCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    try {
      final repo = ref.read(usuarioRepositoryProvider);
      final codigo = _codigoCtrl.text.trim();

      final duplicado =
          await repo.existeCodigo(codigo, excluirUid: _usuarioOriginal?.uid);
      if (duplicado) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Este código ya está en uso por otro usuario')),
          );
        }
        return;
      }

      var fotoUrl = _usuarioOriginal?.fotoUrl ?? '';
      if (_fotoNueva != null) {
        fotoUrl = await StorageService().subirFoto(bytes: _fotoNueva!, carpeta: 'usuarios');
      }

      final usuario = UsuarioModel(
        uid: _usuarioOriginal?.uid ?? '',
        nombre: _nombreCtrl.text.trim(),
        codigo: codigo,
        password: _passwordCtrl.text.trim(),
        rol: _rol,
        estado: _usuarioOriginal?.estado ?? 'activo',
        direccion: _direccionCtrl.text.trim(),
        identidad: _identidadCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim(),
        fotoUrl: fotoUrl,
      );

      if (_esNuevo) {
        await repo.crear(usuario);
      } else {
        await repo.actualizar(usuario);
      }
      ref.invalidate(cobradoresCacheProvider);

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return CeScaffold(
      maxWidth: 640,
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(_esNuevo ? 'Crear Usuario' : 'Editar Usuario'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: SizedBox(
                width: 140,
                child: SelectorFoto(
                  icono: Icons.person_outline,
                  label: 'Foto de perfil',
                  urlActual: _usuarioOriginal?.fotoUrl ?? '',
                  bytesNuevos: _fotoNueva,
                  onSeleccionar: (bytes) => setState(() => _fotoNueva = bytes),
                ),
              ),
            ),
            const SizedBox(height: 16),
            CeSectionCard(
              icono: Icons.badge_outlined,
              titulo: 'Datos de la Cuenta',
              child: Column(
                children: [
                  TextFormField(
                    controller: _nombreCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre completo *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _codigoCtrl,
                    decoration: const InputDecoration(labelText: 'Código único *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: !_verPassword,
                    decoration: InputDecoration(
                      labelText: 'Contraseña *',
                      suffixIcon: IconButton(
                        icon: Icon(_verPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        onPressed: () => setState(() => _verPassword = !_verPassword),
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _rol,
                    decoration: const InputDecoration(labelText: 'Rol *'),
                    items: _roles
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (v) => setState(() => _rol = v ?? 'admin'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            CeSectionCard(
              icono: Icons.contact_page_outlined,
              titulo: 'Datos Personales',
              child: Column(
                children: [
                  TextFormField(
                    controller: _telefonoCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Teléfono *'),
                    validator: (v) =>
                        (v == null || v.trim().length < 8) ? 'Teléfono inválido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _identidadCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Identidad'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _direccionCtrl,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Dirección'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _guardando ? null : _guardar,
                style: ElevatedButton.styleFrom(shape: const StadiumBorder()),
                icon: _guardando
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_esNuevo ? 'Guardar Usuario' : 'Guardar Cambios'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
