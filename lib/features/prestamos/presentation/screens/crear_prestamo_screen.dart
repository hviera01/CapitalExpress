import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/roles.dart';
import '../../../../core/models/cliente_model.dart';
import '../../../../core/models/prestamo_model.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/prestamo_calculos.dart';
import '../../../../core/utils/seleccionar_imagen.dart';
import '../../../../core/widgets/ce_scaffold.dart';
import '../../../../core/widgets/ce_section_card.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../clientes/providers/clientes_provider.dart';
import '../../../solicitudes/providers/solicitudes_provider.dart';
import '../../data/recibo_prestamo_service.dart';
import '../../providers/prestamos_provider.dart';

/// Tambien sirve como "Solicitar Préstamo" (modoSolicitud:true, lo usan
/// los cobradores): mismo formulario y mismos calculos que Crear
/// Préstamo, pero escribe a `solicitudes_prestamo` en vez de
/// `prestamos` directamente -- no genera numeroPrestamo (eso pasa
/// recien si el admin la aprueba) y no imprime recibo, queda pendiente
/// de revision.
class CrearPrestamoScreen extends ConsumerStatefulWidget {
  final String? clienteIdInicial;
  final bool modoSolicitud;

  const CrearPrestamoScreen({super.key, this.clienteIdInicial, this.modoSolicitud = false});

  @override
  ConsumerState<CrearPrestamoScreen> createState() => _CrearPrestamoScreenState();
}

class _CrearPrestamoScreenState extends ConsumerState<CrearPrestamoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _formatoFecha = DateFormat('dd/MM/yyyy');

  ClienteModel? _clienteSeleccionado;
  final _busquedaClienteCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();
  final _interesMensualCtrl = TextEditingController();
  final _interesTotalCtrl = TextEditingController();
  final _moraCtrl = TextEditingController();
  final _cuotasCtrl = TextEditingController();
  final _lugarCtrl = TextEditingController();
  final _garantiaCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();

  bool _usarInteresMensual = true;
  String _plazo = 'Semanal';
  DateTime _fechaInicio = DateTime.now();
  final List<Uint8List> _fotos = [];
  bool _guardando = false;

  @override
  void dispose() {
    _busquedaClienteCtrl.dispose();
    _montoCtrl.dispose();
    _interesMensualCtrl.dispose();
    _interesTotalCtrl.dispose();
    _moraCtrl.dispose();
    _cuotasCtrl.dispose();
    _lugarCtrl.dispose();
    _garantiaCtrl.dispose();
    _observacionesCtrl.dispose();
    super.dispose();
  }

  ResultadoCalculoPrestamo get _calculo {
    final monto = double.tryParse(_montoCtrl.text) ?? 0;
    final cuotas = int.tryParse(_cuotasCtrl.text) ?? 0;
    final dias = calcularDiasEfectivos(_plazo, cuotas, _fechaInicio);
    return calcularInteresYCuota(
      monto: monto,
      cuotas: cuotas,
      plazo: _plazo,
      diasEfectivos: dias,
      usarInteresMensual: _usarInteresMensual,
      interesPct: double.tryParse(_interesMensualCtrl.text) ?? 0,
      interesTotalFijo: double.tryParse(_interesTotalCtrl.text) ?? 0,
    );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_clienteSeleccionado == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Elegí un cliente')));
      return;
    }

    setState(() => _guardando = true);
    try {
      final usuario = ref.read(authProvider).usuario!;
      final monto = double.parse(_montoCtrl.text);
      final cuotas = int.parse(_cuotasCtrl.text);
      final diasEfectivos = calcularDiasEfectivos(_plazo, cuotas, _fechaInicio);
      final calculo = _calculo;
      final proximaFecha = calcularProximaFecha(_fechaInicio, _plazo);

      final storage = StorageService();
      final urlsFotos = <String>[];
      for (final bytes in _fotos) {
        urlsFotos.add(await storage.subirFoto(bytes: bytes, carpeta: 'prestamos'));
      }

      if (widget.modoSolicitud) {
        await ref.read(solicitudRepositoryProvider).crear(
              clienteId: _clienteSeleccionado!.id,
              clienteNombre: _clienteSeleccionado!.nombre,
              monto: monto,
              usarInteresMensual: _usarInteresMensual,
              interesMensual: double.tryParse(_interesMensualCtrl.text) ?? 0,
              interesTotalFijo: double.tryParse(_interesTotalCtrl.text) ?? 0,
              interesCalculado: calculo.interesCalculado,
              moraDiaria: double.tryParse(_moraCtrl.text) ?? 0,
              totalAPagar: calculo.totalAPagar,
              cuotaEstimada: calculo.cuotaEstimada,
              cuotas: cuotas,
              plazo: _plazo,
              fechaInicio: _fechaInicio,
              lugar: _lugarCtrl.text.trim(),
              firma: '',
              garantia: _garantiaCtrl.text.trim(),
              observaciones: _observacionesCtrl.text.trim(),
              fotos: urlsFotos,
              diasEfectivos: diasEfectivos,
              cobradorNombre: usuario.nombre,
              cobradorUid: usuario.uid,
              numeroCobrador: usuario.codigo,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Solicitud enviada, queda pendiente de aprobación')),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      final repo = ref.read(prestamoRepositoryProvider);
      final numeroPrestamo = await repo.generarNumeroPrestamo(_clienteSeleccionado!.nombre);

      final prestamoId = await repo.crear({
        'numeroPrestamo': numeroPrestamo,
        'cliente': _clienteSeleccionado!.nombre,
        'clienteId': _clienteSeleccionado!.id,
        'monto': monto,
        'interes': calculo.interesCalculado,
        'interesMensual': _usarInteresMensual ? (double.tryParse(_interesMensualCtrl.text) ?? 0) : 0.0,
        'interesTotal': calculo.interesCalculado,
        'usarInteresMensual': _usarInteresMensual,
        'interesTotalFijo':
            !_usarInteresMensual ? (double.tryParse(_interesTotalCtrl.text) ?? 0) : 0.0,
        'mora': 0.0,
        'totalPagar': calculo.totalAPagar,
        'cuota': calculo.cuotaEstimada,
        'cuotas': cuotas,
        'plazo': _plazo,
        'fecha': Timestamp.fromDate(_fechaInicio),
        'lugar': _lugarCtrl.text.trim(),
        'firma': '',
        'garantia': _garantiaCtrl.text.trim(),
        'observaciones': _observacionesCtrl.text.trim(),
        'cobrador': usuario.nombre,
        'numeroCobrador': usuario.codigo,
        'cobradorUid': usuario.uid,
        'cobradorAsignado': usuario.uid,
        // El campo real que usan las consultas por cobrador es el array
        // -- sin esto el prestamo recien creado no aparece en Ver
        // Prestamos/Cobros del cobrador hasta reasignarlo a mano.
        'cobradoresAsignados': [usuario.uid],
        'proximoPago': Timestamp.fromDate(proximaFecha),
        'montoPagado': 0.0,
        'saldoAnterior': monto,
        'estado': 'activo',
        'fotos': urlsFotos,
        'diasEfectivos': diasEfectivos,
        'saldo': calculo.totalAPagar,
        'eliminado': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Préstamo creado: N° $numeroPrestamo')),
        );
      }

      if (mounted) {
        ReciboPrestamoService.mostrarVistaPrevia(
          context,
          PrestamoModel(
            prestamoId: prestamoId,
            clienteId: _clienteSeleccionado!.id,
            cliente: _clienteSeleccionado!.nombre,
            monto: monto,
            interes: calculo.interesCalculado,
            totalPagar: calculo.totalAPagar,
            cuota: calculo.cuotaEstimada,
            cuotas: cuotas,
            plazo: _plazo,
            fecha: Timestamp.fromDate(_fechaInicio),
            lugar: _lugarCtrl.text.trim(),
            cobrador: usuario.nombre,
            numeroPrestamo: numeroPrestamo,
            proximoPago: Timestamp.fromDate(proximaFecha),
          ),
        );
      }

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo ${widget.modoSolicitud ? 'enviar la solicitud' : 'crear el préstamo'}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(authProvider).usuario;
    final esAdmin = usuario?.rol == Roles.admin;
    final clientesAsync =
        ref.watch(clientesStreamProvider(esAdmin ? null : usuario?.uid));
    final calculo = _calculo;

    return CeScaffold(
      maxWidth: 720,
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(widget.modoSolicitud ? 'Solicitar Préstamo' : 'Nuevo Préstamo'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CeSectionCard(
              numero: 1,
              icono: Icons.person_outline,
              titulo: 'Cliente',
              child: clientesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, st) => Text('Error al cargar clientes: $e'),
                data: (clientes) {
                  if (_clienteSeleccionado == null && widget.clienteIdInicial != null) {
                    final match = clientes.where((c) => c.id == widget.clienteIdInicial);
                    if (match.isNotEmpty) _clienteSeleccionado = match.first;
                  }
                  return _buscadorCliente(clientes);
                },
              ),
            ),
            const SizedBox(height: 16),
            CeSectionCard(
              numero: 2,
              icono: Icons.payments_outlined,
              titulo: 'Monto y Plazo',
              child: Column(
                children: [
                  TextFormField(
                    controller: _montoCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Monto del préstamo', prefixText: 'L. '),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    validator: (v) =>
                        (double.tryParse(v ?? '') ?? 0) > 0 ? null : 'Ingresá un monto válido',
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Frecuencia de pago',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.6,
                    children: plazosDisponibles.map((p) {
                      final seleccionado = _plazo == p;
                      return OutlinedButton(
                        onPressed: () => setState(() => _plazo = p),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: seleccionado ? CEColors.accent : null,
                          foregroundColor: seleccionado ? Colors.white : CEColors.textPrimary,
                          side: BorderSide(
                              color: seleccionado ? CEColors.accent : CEColors.border),
                        ),
                        child: Text(p, textAlign: TextAlign.center),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _cuotasCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Número de cuotas', prefixIcon: Icon(Icons.format_list_numbered)),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    validator: (v) =>
                        (int.tryParse(v ?? '') ?? 0) > 0 ? null : 'Ingresá las cuotas',
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      final f = await showDatePicker(
                        context: context,
                        initialDate: _fechaInicio,
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (f != null) setState(() => _fechaInicio = f);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: CEColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 18, color: CEColors.accent),
                          const SizedBox(width: 10),
                          Text(
                            'Fecha de inicio: ${_formatoFecha.format(_fechaInicio)}',
                            style: const TextStyle(
                                color: CEColors.accent, fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          const Icon(Icons.edit_outlined, size: 16, color: CEColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            CeSectionCard(
              numero: 3,
              icono: Icons.percent_outlined,
              titulo: 'Interés',
              child: Column(
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('% mensual')),
                      ButtonSegment(value: false, label: Text('Total fijo')),
                    ],
                    selected: {_usarInteresMensual},
                    onSelectionChanged: (s) => setState(() => _usarInteresMensual = s.first),
                  ),
                  const SizedBox(height: 16),
                  if (_usarInteresMensual)
                    TextFormField(
                      controller: _interesMensualCtrl,
                      decoration: const InputDecoration(labelText: 'Porcentaje mensual'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    )
                  else
                    TextFormField(
                      controller: _interesTotalCtrl,
                      decoration: const InputDecoration(labelText: 'Interés total (L.)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _moraCtrl,
                    decoration: const InputDecoration(labelText: 'Mora diaria por retraso (L.)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            CeSectionCard(
              numero: 4,
              icono: Icons.notes_outlined,
              titulo: 'Detalles adicionales',
              child: Column(
                children: [
                  TextFormField(
                    controller: _lugarCtrl,
                    decoration: const InputDecoration(labelText: 'Lugar'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _garantiaCtrl,
                    decoration: const InputDecoration(labelText: 'Garantía'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _observacionesCtrl,
                    decoration: const InputDecoration(labelText: 'Observaciones'),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            CeSectionCard(
              numero: 5,
              icono: Icons.photo_library_outlined,
              titulo: 'Documentos / Fotos',
              child: _seccionFotos(),
            ),
            const SizedBox(height: 16),
            _resumen(calculo),
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
                    : Icon(widget.modoSolicitud ? Icons.send_outlined : Icons.print_outlined),
                label: Text(widget.modoSolicitud ? 'Enviar Solicitud' : 'Guardar e Imprimir'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buscadorCliente(List<ClienteModel> clientes) {
    if (_clienteSeleccionado != null) {
      final c = _clienteSeleccionado!;
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CEColors.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CEColors.accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: CEColors.accent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(c.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() => _clienteSeleccionado = null),
            ),
          ],
        ),
      );
    }

    final query = _busquedaClienteCtrl.text.trim().toLowerCase();
    final resultados = query.length < 2
        ? const <ClienteModel>[]
        : clientes.where((c) => c.nombre.toLowerCase().contains(query)).take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _busquedaClienteCtrl,
          decoration: const InputDecoration(
            hintText: 'Buscar cliente',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 6),
        Text(
          query.length < 2 ? 'Escriba al menos 2 caracteres' : '${resultados.length} resultados',
          style: const TextStyle(fontSize: 12, color: CEColors.textSecondary),
        ),
        if (resultados.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              border: Border.all(color: CEColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: resultados
                  .map((c) => ListTile(
                        dense: true,
                        title: Text(c.nombre),
                        subtitle: c.telefono.isNotEmpty ? Text(c.telefono) : null,
                        onTap: () => setState(() {
                          _clienteSeleccionado = c;
                          _busquedaClienteCtrl.clear();
                        }),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }

  Widget _seccionFotos() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var i = 0; i < _fotos.length; i++)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(_fotos[i], width: 84, height: 84, fit: BoxFit.cover),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: IconButton(
                  icon: const Icon(Icons.cancel, color: CEColors.danger, size: 20),
                  onPressed: () => setState(() => _fotos.removeAt(i)),
                ),
              ),
            ],
          ),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final bytes = await seleccionarImagen(context);
            if (bytes != null) setState(() => _fotos.add(bytes));
          },
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: CEColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CEColors.border),
            ),
            child: const Icon(Icons.add_a_photo_outlined, color: CEColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _resumen(ResultadoCalculoPrestamo c) {
    final cuotas = int.tryParse(_cuotasCtrl.text) ?? 0;
    final dias = calcularDiasEfectivos(_plazo, cuotas, _fechaInicio);
    final meses = dias / 30.0;
    final proximaFecha = calcularProximaFecha(_fechaInicio, _plazo);
    final mora = double.tryParse(_moraCtrl.text) ?? 0;
    final monto = double.tryParse(_montoCtrl.text) ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CEColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resumen del préstamo',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total a pagar',
                      style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
                  Text(formatearLempiras(c.totalAPagar),
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Cuota estimada',
                      style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
                  Text(formatearLempiras(c.cuotaEstimada),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF8FB8FF))),
                ],
              ),
            ],
          ),
          Divider(color: Colors.white.withValues(alpha: 0.1), height: 28),
          Row(
            children: [
              _resumenItem('Monto', formatearLempiras(monto)),
              const SizedBox(width: 12),
              _resumenItem('Interés total', formatearLempiras(c.interesCalculado)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _resumenItem('Cuotas', '$cuotas ($_plazo)'),
              const SizedBox(width: 12),
              _resumenItem('Días efectivos', '$dias ≈ ${meses.toStringAsFixed(1)} meses'),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF8FB8FF)),
                    const SizedBox(width: 8),
                    Text('Primer pago',
                        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
                  ],
                ),
                Text(_formatoFecha.format(proximaFecha),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF8FB8FF))),
              ],
            ),
          ),
          if (mora > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFFFB020)),
                const SizedBox(width: 6),
                Text('Mora diaria: ${formatearLempiras(mora)}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFFFFB020))),
              ],
            ),
          ],
          if (_fotos.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.photo_outlined, size: 14, color: Colors.white.withValues(alpha: 0.5)),
                const SizedBox(width: 6),
                Text('${_fotos.length} foto(s) adjunta(s)',
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _resumenItem(String label, String valor) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: Colors.white.withValues(alpha: 0.45), fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(valor,
              style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
