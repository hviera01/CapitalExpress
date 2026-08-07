import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/roles.dart';
import '../../../../core/models/cliente_model.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/ce_scaffold.dart';
import '../../../../core/widgets/ce_section_card.dart';
import '../../../../core/widgets/selector_foto.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/clientes_provider.dart';

const _estadosCiviles = ['Soltero/a', 'Casado/a', 'Union libre', 'Divorciado/a', 'Viudo/a'];

/// Crear o editar un cliente. Si `clienteId` es null es un cliente nuevo.
class ClienteFormScreen extends ConsumerStatefulWidget {
  final String? clienteId;

  const ClienteFormScreen({super.key, this.clienteId});

  @override
  ConsumerState<ClienteFormScreen> createState() => _ClienteFormScreenState();
}

class _ClienteFormScreenState extends ConsumerState<ClienteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  ClienteModel? _clienteOriginal;
  bool _cargando = true;
  bool _guardando = false;

  final _campos = <String, TextEditingController>{
    'nombre': TextEditingController(),
    'identidad': TextEditingController(),
    'telefono': TextEditingController(),
    'direccionCasa': TextEditingController(),
    'direccionNegocio': TextEditingController(),
    'nombreConyuge': TextEditingController(),
    'identidadConyuge': TextEditingController(),
    'telefonoConyuge': TextEditingController(),
    'referencia1Nombre': TextEditingController(),
    'referencia1Identidad': TextEditingController(),
    'referencia1Telefono': TextEditingController(),
    'referencia1Parentesco': TextEditingController(),
    'referencia1Direccion': TextEditingController(),
    'referencia2Nombre': TextEditingController(),
    'referencia2Identidad': TextEditingController(),
    'referencia2Telefono': TextEditingController(),
    'referencia2Parentesco': TextEditingController(),
    'referencia2Direccion': TextEditingController(),
    'garantiaTexto': TextEditingController(),
  };

  String _estadoCivil = _estadosCiviles.first;

  final _fotos = <String, Uint8List?>{
    'fotoCasaUrl': null,
    'fotoNegocioUrl': null,
    'fotoClienteUrl': null,
    'fotoIdentidadFrenteUrl': null,
    'fotoIdentidadReversoUrl': null,
    'garantiaFotoUrl': null,
  };

  static const _fotosInfo = [
    ('fotoClienteUrl', 'Foto del cliente', Icons.person_outline),
    ('fotoCasaUrl', 'Foto de la casa', Icons.home_outlined),
    ('fotoNegocioUrl', 'Foto del negocio', Icons.storefront_outlined),
    ('fotoIdentidadFrenteUrl', 'Identidad (frente)', Icons.badge_outlined),
    ('fotoIdentidadReversoUrl', 'Identidad (reverso)', Icons.badge_outlined),
    ('garantiaFotoUrl', 'Foto de la garantía', Icons.description_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (widget.clienteId != null) {
      final repo = ref.read(clienteRepositoryProvider);
      final cliente = await repo.obtenerPorId(widget.clienteId!);
      if (cliente != null) {
        _clienteOriginal = cliente;
        _campos['nombre']!.text = cliente.nombre;
        _campos['identidad']!.text = cliente.identidad;
        _campos['telefono']!.text = cliente.telefono;
        _campos['direccionCasa']!.text = cliente.direccionCasa;
        _campos['direccionNegocio']!.text = cliente.direccionNegocio;
        _campos['nombreConyuge']!.text = cliente.nombreConyuge;
        _campos['identidadConyuge']!.text = cliente.identidadConyuge;
        _campos['telefonoConyuge']!.text = cliente.telefonoConyuge;
        _campos['referencia1Nombre']!.text = cliente.referencia1Nombre;
        _campos['referencia1Identidad']!.text = cliente.referencia1Identidad;
        _campos['referencia1Telefono']!.text = cliente.referencia1Telefono;
        _campos['referencia1Parentesco']!.text = cliente.referencia1Parentesco;
        _campos['referencia1Direccion']!.text = cliente.referencia1Direccion;
        _campos['referencia2Nombre']!.text = cliente.referencia2Nombre;
        _campos['referencia2Identidad']!.text = cliente.referencia2Identidad;
        _campos['referencia2Telefono']!.text = cliente.referencia2Telefono;
        _campos['referencia2Parentesco']!.text = cliente.referencia2Parentesco;
        _campos['referencia2Direccion']!.text = cliente.referencia2Direccion;
        _campos['garantiaTexto']!.text = cliente.garantiaTexto;
        if (_estadosCiviles.contains(cliente.estadoCivil)) {
          _estadoCivil = cliente.estadoCivil;
        }
      }
    }
    setState(() => _cargando = false);
  }

  @override
  void dispose() {
    for (final c in _campos.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _urlExistente(String campo) {
    final c = _clienteOriginal;
    if (c == null) return '';
    switch (campo) {
      case 'fotoCasaUrl':
        return c.fotoCasaUrl;
      case 'fotoNegocioUrl':
        return c.fotoNegocioUrl;
      case 'fotoClienteUrl':
        return c.fotoClienteUrl;
      case 'fotoIdentidadFrenteUrl':
        return c.fotoIdentidadFrenteUrl;
      case 'fotoIdentidadReversoUrl':
        return c.fotoIdentidadReversoUrl;
      case 'garantiaFotoUrl':
        return c.garantiaFotoUrl;
      default:
        return '';
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    try {
      final storage = StorageService();
      final urls = <String, String>{};
      for (final entry in _fotos.entries) {
        if (entry.value != null) {
          urls[entry.key] = await storage.subirFoto(
            bytes: entry.value!,
            carpeta: 'clientes',
          );
        } else {
          urls[entry.key] = _urlExistente(entry.key);
        }
      }

      final usuario = ref.read(authProvider).usuario!;
      final cliente = ClienteModel(
        id: _clienteOriginal?.id ?? '',
        nombre: _campos['nombre']!.text.trim(),
        identidad: _campos['identidad']!.text.trim(),
        telefono: _campos['telefono']!.text.trim(),
        direccionCasa: _campos['direccionCasa']!.text.trim(),
        direccionNegocio: _campos['direccionNegocio']!.text.trim(),
        estadoCivil: _estadoCivil,
        nombreConyuge: _campos['nombreConyuge']!.text.trim(),
        identidadConyuge: _campos['identidadConyuge']!.text.trim(),
        telefonoConyuge: _campos['telefonoConyuge']!.text.trim(),
        referencia1Nombre: _campos['referencia1Nombre']!.text.trim(),
        referencia1Identidad: _campos['referencia1Identidad']!.text.trim(),
        referencia1Telefono: _campos['referencia1Telefono']!.text.trim(),
        referencia1Parentesco: _campos['referencia1Parentesco']!.text.trim(),
        referencia1Direccion: _campos['referencia1Direccion']!.text.trim(),
        referencia2Nombre: _campos['referencia2Nombre']!.text.trim(),
        referencia2Identidad: _campos['referencia2Identidad']!.text.trim(),
        referencia2Telefono: _campos['referencia2Telefono']!.text.trim(),
        referencia2Parentesco: _campos['referencia2Parentesco']!.text.trim(),
        referencia2Direccion: _campos['referencia2Direccion']!.text.trim(),
        fotoCasaUrl: urls['fotoCasaUrl']!,
        fotoNegocioUrl: urls['fotoNegocioUrl']!,
        fotoClienteUrl: urls['fotoClienteUrl']!,
        fotoIdentidadFrenteUrl: urls['fotoIdentidadFrenteUrl']!,
        fotoIdentidadReversoUrl: urls['fotoIdentidadReversoUrl']!,
        fotoReciboLuzUrl: _clienteOriginal?.fotoReciboLuzUrl ?? '',
        garantiaTexto: _campos['garantiaTexto']!.text.trim(),
        garantiaFotoUrl: urls['garantiaFotoUrl']!,
        estado: _clienteOriginal?.estado ?? 'activo',
        tienePrestamo: _clienteOriginal?.tienePrestamo ?? false,
        cobradorAsignado: _clienteOriginal?.cobradorAsignado ??
            (usuario.rol == Roles.cobrador ? usuario.uid : ''),
      );

      final repo = ref.read(clienteRepositoryProvider);
      if (_clienteOriginal == null) {
        await repo.crear(cliente);
      } else {
        await repo.actualizar(cliente);
      }

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
      maxWidth: 720,
      appBar: AppBar(
        title: Text(_clienteOriginal == null ? 'Crear Nuevo Cliente' : 'Editar cliente'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CeSectionCard(
              icono: Icons.badge_outlined,
              titulo: 'Datos Personales',
              child: Column(
                children: [
                  _campo('nombre', 'Nombre *', requerido: true),
                  _campo('identidad', 'Identidad *', requerido: true),
                  _campo('telefono', 'Teléfono *', requerido: true, tipo: TextInputType.phone),
                ],
              ),
            ),
            const SizedBox(height: 16),
            CeSectionCard(
              icono: Icons.work_outline,
              titulo: 'Datos de Trabajo',
              child: Column(
                children: [
                  _campo('garantiaTexto', 'Garantía', lineas: 2),
                  _campo('direccionCasa', 'Dirección Casa'),
                  _campo('direccionNegocio', 'Dirección Negocio', ultimo: true),
                ],
              ),
            ),
            const SizedBox(height: 16),
            CeSectionCard(
              icono: Icons.favorite_outline,
              titulo: 'Estado Civil',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _estadosCiviles
                    .map((e) => ChoiceChip(
                          label: Text(e),
                          selected: _estadoCivil == e,
                          onSelected: (_) => setState(() => _estadoCivil = e),
                        ))
                    .toList(),
              ),
            ),
            if (_estadoCivil != 'Soltero/a') ...[
              const SizedBox(height: 16),
              CeSectionCard(
                icono: Icons.people_outline,
                titulo: 'Cónyuge',
                child: Column(
                  children: [
                    _campo('nombreConyuge', 'Nombre del cónyuge'),
                    _campo('identidadConyuge', 'Identidad del cónyuge'),
                    _campo('telefonoConyuge', 'Teléfono del cónyuge',
                        tipo: TextInputType.phone, ultimo: true),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            CeSectionCard(
              icono: Icons.contacts_outlined,
              titulo: 'Referencias Personales',
              child: Column(
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Referencia 1',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  const SizedBox(height: 8),
                  _campo('referencia1Nombre', 'Nombre'),
                  _campo('referencia1Identidad', 'Identidad'),
                  _campo('referencia1Telefono', 'Teléfono', tipo: TextInputType.phone),
                  _campo('referencia1Parentesco', 'Parentesco'),
                  _campo('referencia1Direccion', 'Dirección'),
                  const Divider(height: 28),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Referencia 2',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  const SizedBox(height: 8),
                  _campo('referencia2Nombre', 'Nombre'),
                  _campo('referencia2Identidad', 'Identidad'),
                  _campo('referencia2Telefono', 'Teléfono', tipo: TextInputType.phone),
                  _campo('referencia2Parentesco', 'Parentesco'),
                  _campo('referencia2Direccion', 'Dirección', ultimo: true),
                ],
              ),
            ),
            const SizedBox(height: 16),
            CeSectionCard(
              icono: Icons.photo_library_outlined,
              titulo: 'Documentos y Fotos',
              child: GridView.count(
                crossAxisCount: esEscritorio(context) ? 3 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 14,
                mainAxisSpacing: 18,
                childAspectRatio: 0.82,
                children: _fotosInfo
                    .map(
                      (f) => SelectorFoto(
                        icono: f.$3,
                        label: f.$2,
                        urlActual: _urlExistente(f.$1),
                        bytesNuevos: _fotos[f.$1],
                        onSeleccionar: (bytes) => setState(() => _fotos[f.$1] = bytes),
                      ),
                    )
                    .toList(),
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
                label: Text(_clienteOriginal == null ? 'Guardar Cliente' : 'Guardar Cambios'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _campo(
    String key,
    String label, {
    bool requerido = false,
    TextInputType tipo = TextInputType.text,
    int lineas = 1,
    bool ultimo = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: ultimo ? 0 : 12),
      child: TextFormField(
        controller: _campos[key],
        decoration: InputDecoration(labelText: label),
        keyboardType: tipo,
        maxLines: lineas,
        validator: requerido
            ? (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null
            : null,
      ),
    );
  }
}
