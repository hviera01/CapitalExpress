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

const _estadosCiviles = ['Soltero', 'Casado', 'Union libre', 'Divorciado', 'Viudo'];

/// Crear o editar un cliente. Si `clienteId` es null es un cliente nuevo.
/// [clienteInicial] es opcional: si quien navega aca ya tiene el
/// ClienteModel en memoria (la lista, el resumen), se lo pasa por
/// `extra` del router y esta pantalla se salta el viaje redondo a
/// Firestore que antes hacia SIEMPRE antes de mostrar el formulario.
class ClienteFormScreen extends ConsumerStatefulWidget {
  final String? clienteId;
  final ClienteModel? clienteInicial;

  const ClienteFormScreen({super.key, this.clienteId, this.clienteInicial});

  @override
  ConsumerState<ClienteFormScreen> createState() => _ClienteFormScreenState();
}

class _ClienteFormScreenState extends ConsumerState<ClienteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  ClienteModel? _clienteOriginal;
  late bool _cargando = widget.clienteInicial == null && widget.clienteId != null;
  bool _guardando = false;

  final _campos = <String, TextEditingController>{
    'nombre': TextEditingController(),
    'identidad': TextEditingController(),
    'telefono': TextEditingController(),
    'nombreEmpresa': TextEditingController(),
    'direccionCasa': TextEditingController(),
    'direccionNegocio': TextEditingController(),
    'garantia': TextEditingController(),
    'ref1Nombre': TextEditingController(),
    'ref1Identidad': TextEditingController(),
    'ref1Telefono': TextEditingController(),
    'ref1Parentesco': TextEditingController(),
    'ref1Direccion': TextEditingController(),
    'ref2Nombre': TextEditingController(),
    'ref2Identidad': TextEditingController(),
    'ref2Telefono': TextEditingController(),
    'ref2Parentesco': TextEditingController(),
    'ref2Direccion': TextEditingController(),
  };

  String _estadoCivil = _estadosCiviles.first;

  final _fotos = <String, Uint8List?>{
    'fotoCasaUrl': null,
    'fotoNegocioUrl': null,
    'fotoPersonaUrl': null,
    'fotoIdentidadFrenteUrl': null,
    'fotoIdentidadReversoUrl': null,
    'fotoReciboLuzUrl': null,
    'fotoGarantiaUrl': null,
    'fotoExtra1': null,
    'fotoExtra2': null,
    'fotoExtra3': null,
  };

  static const _fotosInfo = [
    ('fotoPersonaUrl', 'Foto del cliente', Icons.person_outline),
    ('fotoCasaUrl', 'Foto de la casa', Icons.home_outlined),
    ('fotoNegocioUrl', 'Foto del negocio', Icons.storefront_outlined),
    ('fotoIdentidadFrenteUrl', 'Identidad (frente)', Icons.badge_outlined),
    ('fotoIdentidadReversoUrl', 'Identidad (reverso)', Icons.badge_outlined),
    ('fotoReciboLuzUrl', 'Recibo de luz', Icons.receipt_long_outlined),
    ('fotoGarantiaUrl', 'Foto de la garantía', Icons.description_outlined),
    ('fotoExtra1', 'Foto Extra 1', Icons.add_a_photo_outlined),
    ('fotoExtra2', 'Foto Extra 2', Icons.add_a_photo_outlined),
    ('fotoExtra3', 'Foto Extra 3', Icons.add_a_photo_outlined),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.clienteInicial != null) {
      // Ya lo teniamos en memoria (lista/resumen) -- se aplica directo,
      // sin el viaje redondo a Firestore que antes se hacia siempre
      // antes de poder ver el formulario de edicion.
      _aplicarCliente(widget.clienteInicial!);
    } else if (widget.clienteId != null) {
      _cargar();
    }
  }

  void _aplicarCliente(ClienteModel cliente) {
    _clienteOriginal = cliente;
    _campos['nombre']!.text = cliente.nombre;
    _campos['identidad']!.text = cliente.identidad;
    _campos['telefono']!.text = cliente.telefono;
    _campos['nombreEmpresa']!.text = cliente.nombreEmpresa;
    _campos['direccionCasa']!.text = cliente.direccionCasa;
    _campos['direccionNegocio']!.text = cliente.direccionNegocio;
    _campos['garantia']!.text = cliente.garantia;
    _campos['ref1Nombre']!.text = cliente.ref1.nombre;
    _campos['ref1Identidad']!.text = cliente.ref1.identidad;
    _campos['ref1Telefono']!.text = cliente.ref1.telefono;
    _campos['ref1Parentesco']!.text = cliente.ref1.parentesco;
    _campos['ref1Direccion']!.text = cliente.ref1.direccion;
    _campos['ref2Nombre']!.text = cliente.ref2.nombre;
    _campos['ref2Identidad']!.text = cliente.ref2.identidad;
    _campos['ref2Telefono']!.text = cliente.ref2.telefono;
    _campos['ref2Parentesco']!.text = cliente.ref2.parentesco;
    _campos['ref2Direccion']!.text = cliente.ref2.direccion;
    if (_estadosCiviles.contains(cliente.estadoCivil)) {
      _estadoCivil = cliente.estadoCivil;
    }
  }

  Future<void> _cargar() async {
    final repo = ref.read(clienteRepositoryProvider);
    final cliente = await repo.obtenerPorId(widget.clienteId!);
    if (cliente != null) _aplicarCliente(cliente);
    if (mounted) setState(() => _cargando = false);
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
      case 'fotoPersonaUrl':
        return c.fotoPersonaUrl;
      case 'fotoIdentidadFrenteUrl':
        return c.fotoIdentidadFrenteUrl;
      case 'fotoIdentidadReversoUrl':
        return c.fotoIdentidadReversoUrl;
      case 'fotoReciboLuzUrl':
        return c.fotoReciboLuzUrl;
      case 'fotoGarantiaUrl':
        return c.fotoGarantiaUrl;
      case 'fotoExtra1':
        return c.fotoExtra1;
      case 'fotoExtra2':
        return c.fotoExtra2;
      case 'fotoExtra3':
        return c.fotoExtra3;
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
        nombreEmpresa: _campos['nombreEmpresa']!.text.trim(),
        direccionCasa: _campos['direccionCasa']!.text.trim(),
        direccionNegocio: _campos['direccionNegocio']!.text.trim(),
        estadoCivil: _estadoCivil,
        ref1: ReferenciaPersonal(
          nombre: _campos['ref1Nombre']!.text.trim(),
          identidad: _campos['ref1Identidad']!.text.trim(),
          telefono: _campos['ref1Telefono']!.text.trim(),
          parentesco: _campos['ref1Parentesco']!.text.trim(),
          direccion: _campos['ref1Direccion']!.text.trim(),
        ),
        ref2: ReferenciaPersonal(
          nombre: _campos['ref2Nombre']!.text.trim(),
          identidad: _campos['ref2Identidad']!.text.trim(),
          telefono: _campos['ref2Telefono']!.text.trim(),
          parentesco: _campos['ref2Parentesco']!.text.trim(),
          direccion: _campos['ref2Direccion']!.text.trim(),
        ),
        fotoCasaUrl: urls['fotoCasaUrl']!,
        fotoNegocioUrl: urls['fotoNegocioUrl']!,
        fotoPersonaUrl: urls['fotoPersonaUrl']!,
        fotoIdentidadFrenteUrl: urls['fotoIdentidadFrenteUrl']!,
        fotoIdentidadReversoUrl: urls['fotoIdentidadReversoUrl']!,
        fotoReciboLuzUrl: urls['fotoReciboLuzUrl']!,
        fotoExtra1: urls['fotoExtra1']!,
        fotoExtra2: urls['fotoExtra2']!,
        fotoExtra3: urls['fotoExtra3']!,
        garantia: _campos['garantia']!.text.trim(),
        fotoGarantiaUrl: urls['fotoGarantiaUrl']!,
        estado: _clienteOriginal?.estado ?? 'activo',
        tienePrestamo: _clienteOriginal?.tienePrestamo ?? false,
        cobradorAsignado: _clienteOriginal?.cobradorAsignado ??
            (usuario.rol == Roles.cobrador ? usuario.uid : ''),
        cobrador: _clienteOriginal?.cobrador ?? usuario.nombre,
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
        leading: const BackButton(),
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
                  _campo('nombreEmpresa', 'Empresa'),
                  _campo('garantia', 'Garantía', lineas: 2),
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
            const SizedBox(height: 16),
            CeSectionCard(
              icono: Icons.contacts_outlined,
              titulo: 'Referencias Personales',
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: Column(
                  children: [
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 8),
                      title: const Text('Referencia 1',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      children: [
                        _campo('ref1Nombre', 'Nombre'),
                        _campo('ref1Identidad', 'Identidad'),
                        _campo('ref1Telefono', 'Teléfono', tipo: TextInputType.phone),
                        _campo('ref1Parentesco', 'Parentesco'),
                        _campo('ref1Direccion', 'Dirección', ultimo: true),
                      ],
                    ),
                    const Divider(height: 1),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 8, top: 8),
                      title: const Text('Referencia 2',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      children: [
                        _campo('ref2Nombre', 'Nombre'),
                        _campo('ref2Identidad', 'Identidad'),
                        _campo('ref2Telefono', 'Teléfono', tipo: TextInputType.phone),
                        _campo('ref2Parentesco', 'Parentesco'),
                        _campo('ref2Direccion', 'Dirección', ultimo: true),
                      ],
                    ),
                  ],
                ),
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
