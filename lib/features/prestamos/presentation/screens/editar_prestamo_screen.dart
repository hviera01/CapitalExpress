import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/roles.dart';
import '../../../../core/models/prestamo_model.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/prestamo_calculos.dart';
import '../../../../core/widgets/ce_scaffold.dart';
import '../../../../core/widgets/ce_section_card.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../solicitudes/providers/solicitud_edicion_provider.dart';
import '../../providers/prestamos_provider.dart';

const _estadosPrestamo = ['activo', 'mora', 'saldado'];

/// Edicion de datos del prestamo, incluidos los campos financieros
/// (monto, total a pagar, cuotas, monto de cuota) -- a diferencia de
/// antes, que solo dejaba tocar datos administrativos. Unica
/// validacion dura: el nuevo total a pagar no puede quedar por debajo
/// de lo que el cliente YA pago (`montoPagado`), para no dejar un
/// saldo negativo/imposible. El saldo se recalcula solo al guardar
/// (`totalPagar - montoPagado`) para que quede consistente de
/// inmediato en toda la app, no solo despues del proximo pago.
class EditarPrestamoScreen extends ConsumerStatefulWidget {
  final String prestamoId;
  final PrestamoModel? prestamoInicial;
  // Ver ClienteFormScreen -- mismo mecanismo de "modo solicitud" +
  // permiso otorgado, aplicado a prestamos.
  final bool modoSolicitud;
  final Map<String, dynamic>? valoresPropuestos;
  final String? solicitudEdicionId;

  const EditarPrestamoScreen({
    super.key,
    required this.prestamoId,
    this.prestamoInicial,
    this.modoSolicitud = false,
    this.valoresPropuestos,
    this.solicitudEdicionId,
  });

  @override
  ConsumerState<EditarPrestamoScreen> createState() => _EditarPrestamoScreenState();
}

class _EditarPrestamoScreenState extends ConsumerState<EditarPrestamoScreen> {
  final _formKey = GlobalKey<FormState>();
  PrestamoModel? _prestamo;
  late bool _cargando = widget.prestamoInicial == null;
  bool _guardando = false;
  bool _verificandoPermiso = false;
  bool _bloqueadoPorPermiso = false;

  final _lugarCtrl = TextEditingController();
  final _garantiaCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();
  final _totalPagarCtrl = TextEditingController();
  final _cuotasCtrl = TextEditingController();
  final _cuotaCtrl = TextEditingController();
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
      _verificarPermiso();
    } else {
      _cargar();
    }
  }

  void _aplicarPrestamo(PrestamoModel p) {
    _prestamo = p;
    _lugarCtrl.text = p.lugar;
    _garantiaCtrl.text = p.garantia;
    _observacionesCtrl.text = p.observaciones;
    _montoCtrl.text = p.monto.toStringAsFixed(2);
    final totalPagar = p.totalPagar > 0 ? p.totalPagar : (p.monto + p.interes);
    _totalPagarCtrl.text = totalPagar.toStringAsFixed(2);
    _cuotasCtrl.text = '${p.cuotas}';
    _cuotaCtrl.text = p.cuota.toStringAsFixed(2);
    if (plazosDisponibles.contains(p.plazo)) _plazo = p.plazo;
    if (_estadosPrestamo.contains(p.estado)) _estado = p.estado;

    final propuestos = widget.valoresPropuestos;
    if (propuestos != null) {
      if (propuestos['lugar'] != null) _lugarCtrl.text = '${propuestos['lugar']}';
      if (propuestos['garantia'] != null) _garantiaCtrl.text = '${propuestos['garantia']}';
      if (propuestos['observaciones'] != null) {
        _observacionesCtrl.text = '${propuestos['observaciones']}';
      }
      if (propuestos['monto'] != null) _montoCtrl.text = '${propuestos['monto']}';
      if (propuestos['totalPagar'] != null) _totalPagarCtrl.text = '${propuestos['totalPagar']}';
      if (propuestos['cuotas'] != null) _cuotasCtrl.text = '${propuestos['cuotas']}';
      if (propuestos['cuota'] != null) _cuotaCtrl.text = '${propuestos['cuota']}';
      final plazoProp = propuestos['plazo'] as String?;
      if (plazoProp != null && plazosDisponibles.contains(plazoProp)) _plazo = plazoProp;
      final estadoProp = propuestos['estado'] as String?;
      if (estadoProp != null && _estadosPrestamo.contains(estadoProp)) _estado = estadoProp;
    }
  }

  Future<void> _cargar() async {
    final p = await ref.read(prestamoRepositoryProvider).obtenerPorId(widget.prestamoId);
    if (p != null) _aplicarPrestamo(p);
    if (mounted) setState(() => _cargando = false);
    _verificarPermiso();
  }

  bool _puedeEditarLibre(String? rol) {
    if (Roles.esAdminOEquivalente(rol)) return true;
    final fc = _prestamo?.fechaCreacion;
    if (fc == null) return false;
    return DateTime.now().difference(fc.toDate()) < const Duration(hours: 1);
  }

  Future<void> _verificarPermiso() async {
    if (widget.modoSolicitud || widget.solicitudEdicionId != null) return;
    if (_prestamo == null) return;
    final usuario = ref.read(authProvider).usuario;
    if (_puedeEditarLibre(usuario?.rol)) return;
    setState(() => _verificandoPermiso = true);
    final permiso =
        await ref.read(solicitudEdicionRepositoryProvider).permisoActivoPara(_prestamo!.prestamoId);
    if (!mounted) return;
    setState(() {
      _verificandoPermiso = false;
      _bloqueadoPorPermiso = permiso == null;
    });
  }

  @override
  void dispose() {
    _lugarCtrl.dispose();
    _garantiaCtrl.dispose();
    _observacionesCtrl.dispose();
    _montoCtrl.dispose();
    _totalPagarCtrl.dispose();
    _cuotasCtrl.dispose();
    _cuotaCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviarSolicitud() async {
    if (!_formKey.currentState!.validate()) return;
    final p = _prestamo;
    if (p == null) return;

    final nuevoTotalPagar = double.tryParse(_totalPagarCtrl.text.replaceAll(',', '.'));
    final nuevoMonto = double.tryParse(_montoCtrl.text.replaceAll(',', '.'));
    final nuevaCuota = double.tryParse(_cuotaCtrl.text.replaceAll(',', '.'));
    final nuevasCuotas = int.tryParse(_cuotasCtrl.text);
    if (nuevoTotalPagar == null || nuevoMonto == null || nuevaCuota == null || nuevasCuotas == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Revisá los montos, hay uno inválido')));
      return;
    }
    if (nuevoTotalPagar < p.montoPagado - 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'El total a pagar (${formatearLempiras(nuevoTotalPagar)}) no puede ser menor a lo ya pagado (${formatearLempiras(p.montoPagado)})'),
      ));
      return;
    }

    final totalPagarOriginal = p.totalPagar > 0 ? p.totalPagar : (p.monto + p.interes);
    final nuevos = <String, dynamic>{
      'lugar': _lugarCtrl.text.trim(),
      'garantia': _garantiaCtrl.text.trim(),
      'observaciones': _observacionesCtrl.text.trim(),
      'plazo': _plazo,
      'estado': _estado,
      'monto': nuevoMonto,
      'totalPagar': nuevoTotalPagar,
      'cuotas': nuevasCuotas,
      'cuota': nuevaCuota,
    };
    final anteriores = <String, dynamic>{
      'lugar': p.lugar,
      'garantia': p.garantia,
      'observaciones': p.observaciones,
      'plazo': p.plazo,
      'estado': p.estado,
      'monto': p.monto,
      'totalPagar': totalPagarOriginal,
      'cuotas': p.cuotas,
      'cuota': p.cuota,
    };
    final valoresNuevos = <String, dynamic>{};
    final valoresAnteriores = <String, dynamic>{};
    for (final campo in nuevos.keys) {
      if ('${nuevos[campo]}' != '${anteriores[campo]}') {
        valoresNuevos[campo] = nuevos[campo];
        valoresAnteriores[campo] = anteriores[campo];
      }
    }

    if (valoresNuevos.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No hiciste ningún cambio')));
      return;
    }

    setState(() => _guardando = true);
    try {
      final usuario = ref.read(authProvider).usuario!;
      await ref.read(solicitudEdicionRepositoryProvider).crear(
            entidadTipo: 'prestamo',
            entidadId: p.prestamoId,
            entidadNombre: 'N° ${p.numeroPrestamo} - ${p.cliente}',
            valoresNuevos: valoresNuevos,
            valoresAnteriores: valoresAnteriores,
            solicitanteUid: usuario.uid,
            solicitanteNombre: usuario.nombre,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud enviada, un admin la va a revisar')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo enviar la solicitud: $e')));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _guardar() async {
    if (widget.modoSolicitud) return _enviarSolicitud();
    if (!_formKey.currentState!.validate()) return;
    final p = _prestamo;
    if (p == null) return;

    final nuevoTotalPagar = double.tryParse(_totalPagarCtrl.text.replaceAll(',', '.'));
    final nuevoMonto = double.tryParse(_montoCtrl.text.replaceAll(',', '.'));
    final nuevaCuota = double.tryParse(_cuotaCtrl.text.replaceAll(',', '.'));
    final nuevasCuotas = int.tryParse(_cuotasCtrl.text);
    if (nuevoTotalPagar == null || nuevoMonto == null || nuevaCuota == null || nuevasCuotas == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Revisá los montos, hay uno inválido')));
      return;
    }

    // Unica validacion dura: no se puede dejar un total a pagar menor
    // a lo que el cliente ya pago -- eso dejaria un saldo negativo/
    // imposible de explicar.
    if (nuevoTotalPagar < p.montoPagado - 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'El total a pagar (${formatearLempiras(nuevoTotalPagar)}) no puede ser menor a lo ya pagado (${formatearLempiras(p.montoPagado)})'),
      ));
      return;
    }

    setState(() => _guardando = true);
    try {
      final usuario = ref.read(authProvider).usuario!;
      final nuevoSaldo = (nuevoTotalPagar - p.montoPagado).clamp(0.0, double.infinity);
      await ref.read(prestamoRepositoryProvider).actualizar(
        widget.prestamoId,
        {
          'lugar': _lugarCtrl.text.trim(),
          'garantia': _garantiaCtrl.text.trim(),
          'observaciones': _observacionesCtrl.text.trim(),
          'plazo': _plazo,
          'estado': _estado,
          'monto': nuevoMonto,
          'totalPagar': nuevoTotalPagar,
          'cuotas': nuevasCuotas,
          'cuota': nuevaCuota,
          'saldo': nuevoSaldo,
        },
        usuarioUid: usuario.uid,
        usuarioNombre: usuario.nombre,
        descripcionPrestamo: 'N° ${p.numeroPrestamo} - ${p.cliente}',
      );
      final solicitudId = widget.solicitudEdicionId;
      if (solicitudId != null) {
        await ref.read(solicitudEdicionRepositoryProvider).marcarAplicada(
              solicitudId,
              usuarioUid: usuario.uid,
              usuarioNombre: usuario.nombre,
              descripcion: 'N° ${p.numeroPrestamo} - ${p.cliente}',
            );
      }
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

  String? _validarMonto(String? v) {
    if (v == null || v.trim().isEmpty) return 'Campo requerido';
    final n = double.tryParse(v.replaceAll(',', '.'));
    if (n == null || n < 0) return 'Monto inválido';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando || _verificandoPermiso) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_prestamo == null) {
      return const Scaffold(body: Center(child: Text('Préstamo no encontrado')));
    }

    if (_bloqueadoPorPermiso) {
      final p = _prestamo!;
      return Scaffold(
        appBar: AppBar(leading: const BackButton(), title: const Text('Editar préstamo')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_clock_outlined, size: 40),
                const SizedBox(height: 12),
                const Text('Ya pasó la hora libre para editar este préstamo',
                    textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const Text('Mandá una solicitud de edición para que un admin la revise.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Solicitar edición'),
                  onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(
                      builder: (_) => EditarPrestamoScreen(
                          prestamoId: p.prestamoId, prestamoInicial: p, modoSolicitud: true))),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return CeScaffold(
      maxWidth: 720,
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(widget.modoSolicitud
            ? 'Solicitar edición de préstamo'
            : 'Editar N° ${_prestamo!.numeroPrestamo}'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CeSectionCard(
              icono: Icons.payments_outlined,
              titulo: 'Montos',
              child: Column(
                children: [
                  Text('Ya pagado: ${formatearLempiras(_prestamo!.montoPagado)} -- el total a pagar '
                      'no puede quedar por debajo de esto.',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _montoCtrl,
                    decoration: const InputDecoration(labelText: 'Monto (capital)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: _validarMonto,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _totalPagarCtrl,
                    decoration: const InputDecoration(labelText: 'Total a pagar'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: _validarMonto,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _cuotasCtrl,
                    decoration: const InputDecoration(labelText: 'Cantidad de cuotas'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n <= 0) return 'Cantidad inválida';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _cuotaCtrl,
                    decoration: const InputDecoration(labelText: 'Monto de cada cuota'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: _validarMonto,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            CeSectionCard(
              icono: Icons.edit_outlined,
              titulo: 'Datos administrativos',
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
                label: Text(widget.modoSolicitud ? 'Enviar solicitud' : 'Guardar cambios'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
