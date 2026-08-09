import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/prestamo_model.dart';
import '../../../../core/utils/prestamo_calculos.dart';
import '../../../../core/widgets/ce_scaffold.dart';
import '../../../../core/widgets/ce_section_card.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/prestamos_provider.dart';

const _estadosPrestamo = ['activo', 'mora', 'saldado'];

/// Edicion de datos administrativos del prestamo. No toca interes/saldo/
/// totalPagar: esos numeros dependen de la cascada de pagos ya aplicada
/// (RegistrarPagoScreen.kt) y recalcularlos aca sin esa logica completa
/// arriesgaria desincronizar el saldo real del cliente.
class EditarPrestamoScreen extends ConsumerStatefulWidget {
  final String prestamoId;
  final PrestamoModel? prestamoInicial;

  const EditarPrestamoScreen({super.key, required this.prestamoId, this.prestamoInicial});

  @override
  ConsumerState<EditarPrestamoScreen> createState() => _EditarPrestamoScreenState();
}

class _EditarPrestamoScreenState extends ConsumerState<EditarPrestamoScreen> {
  final _formKey = GlobalKey<FormState>();
  PrestamoModel? _prestamo;
  late bool _cargando = widget.prestamoInicial == null;
  bool _guardando = false;

  final _lugarCtrl = TextEditingController();
  final _garantiaCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();
  String _plazo = 'Semanal';
  String _estado = 'activo';

  @override
  void initState() {
    super.initState();
    // Si Detalle del Prestamo ya nos paso el modelo por `extra` (el
    // caso normal, siempre viene de esa pantalla), nos ahorramos el
    // viaje redondo a Firestore que antes se hacia siempre.
    if (widget.prestamoInicial != null) {
      _aplicarPrestamo(widget.prestamoInicial!);
    } else {
      _cargar();
    }
  }

  void _aplicarPrestamo(PrestamoModel p) {
    _prestamo = p;
    _lugarCtrl.text = p.lugar;
    _garantiaCtrl.text = p.garantia;
    _observacionesCtrl.text = p.observaciones;
    if (plazosDisponibles.contains(p.plazo)) _plazo = p.plazo;
    if (_estadosPrestamo.contains(p.estado)) _estado = p.estado;
  }

  Future<void> _cargar() async {
    final p = await ref.read(prestamoRepositoryProvider).obtenerPorId(widget.prestamoId);
    if (p != null) _aplicarPrestamo(p);
    if (mounted) setState(() => _cargando = false);
  }

  @override
  void dispose() {
    _lugarCtrl.dispose();
    _garantiaCtrl.dispose();
    _observacionesCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      final usuario = ref.read(authProvider).usuario!;
      final p = _prestamo;
      await ref.read(prestamoRepositoryProvider).actualizar(
        widget.prestamoId,
        {
          'lugar': _lugarCtrl.text.trim(),
          'garantia': _garantiaCtrl.text.trim(),
          'observaciones': _observacionesCtrl.text.trim(),
          'plazo': _plazo,
          'estado': _estado,
        },
        usuarioUid: usuario.uid,
        usuarioNombre: usuario.nombre,
        descripcionPrestamo: p != null ? 'N° ${p.numeroPrestamo} - ${p.cliente}' : '',
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
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
    if (_prestamo == null) {
      return const Scaffold(body: Center(child: Text('Préstamo no encontrado')));
    }

    return CeScaffold(
      maxWidth: 720,
      appBar: AppBar(
        leading: const BackButton(),title: Text('Editar N° ${_prestamo!.numeroPrestamo}')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CeSectionCard(
              icono: Icons.edit_outlined,
              titulo: 'Datos editables',
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _plazo,
                    decoration: const InputDecoration(labelText: 'Plazo'),
                    items: plazosDisponibles
                        .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (v) => setState(() => _plazo = v ?? _plazo),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _estado,
                    decoration: const InputDecoration(labelText: 'Estado'),
                    items: _estadosPrestamo
                        .map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase())))
                        .toList(),
                    onChanged: (v) => setState(() => _estado = v ?? _estado),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _lugarCtrl,
                    decoration: const InputDecoration(labelText: 'Lugar'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _garantiaCtrl,
                    decoration: const InputDecoration(labelText: 'Garantía'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _observacionesCtrl,
                    decoration: const InputDecoration(labelText: 'Observaciones'),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
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
                label: const Text('Guardar cambios'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
