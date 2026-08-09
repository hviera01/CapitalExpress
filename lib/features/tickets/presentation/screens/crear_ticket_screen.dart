import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/roles.dart';
import '../../../../core/widgets/ce_scaffold.dart';
import '../../../../core/widgets/ce_section_card.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/tickets_provider.dart';
import '../widgets/selector_capturas.dart';

class CrearTicketScreen extends ConsumerStatefulWidget {
  const CrearTicketScreen({super.key});

  @override
  ConsumerState<CrearTicketScreen> createState() => _CrearTicketScreenState();
}

class _CrearTicketScreenState extends ConsumerState<CrearTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  String _tipo = 'problema';
  final _fotos = <Uint8List>[];
  bool _guardando = false;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final usuario = ref.read(authProvider).usuario!;
      await ref.read(ticketRepositoryProvider).crear(
            tipo: _tipo,
            titulo: _tituloCtrl.text.trim(),
            descripcion: _descripcionCtrl.text.trim(),
            fotos: _fotos,
            uid: usuario.uid,
            nombre: usuario.nombre,
            rol: usuario.rol,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo enviar: $e')));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esAdmin = ref.watch(authProvider).usuario?.rol == Roles.admin;

    return CeScaffold(
      maxWidth: 720,
      appBar: AppBar(leading: const BackButton(), title: const Text('Nuevo Ticket')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CeSectionCard(
              icono: Icons.confirmation_number_outlined,
              titulo: 'Tipo',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Reportar un problema'),
                    selected: _tipo == 'problema',
                    onSelected: (_) => setState(() => _tipo = 'problema'),
                  ),
                  if (esAdmin)
                    ChoiceChip(
                      label: const Text('Pedir algo nuevo'),
                      selected: _tipo == 'nuevo',
                      onSelected: (_) => setState(() => _tipo = 'nuevo'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            CeSectionCard(
              icono: Icons.edit_note_outlined,
              titulo: 'Detalle',
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      controller: _tituloCtrl,
                      decoration: const InputDecoration(labelText: 'Título *'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
                    ),
                  ),
                  TextFormField(
                    controller: _descripcionCtrl,
                    minLines: 4,
                    maxLines: 8,
                    decoration: InputDecoration(
                      labelText: _tipo == 'problema' ? 'Explicá exactamente qué está pasando *' : 'Describí qué te gustaría agregar *',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            CeSectionCard(
              icono: Icons.image_outlined,
              titulo: 'Capturas (opcional, hasta 3)',
              child: SelectorCapturas(fotos: _fotos, onCambiar: (f) => setState(() {
                _fotos
                  ..clear()
                  ..addAll(f);
              })),
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
                    : const Icon(Icons.send_outlined),
                label: const Text('Enviar ticket'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
