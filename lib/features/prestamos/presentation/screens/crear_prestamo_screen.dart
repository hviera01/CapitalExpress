import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/roles.dart';
import '../../../../core/models/cliente_model.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/prestamo_calculos.dart';
import '../../../../core/utils/seleccionar_imagen.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../clientes/providers/clientes_provider.dart';
import '../../providers/prestamos_provider.dart';

class CrearPrestamoScreen extends ConsumerStatefulWidget {
  final String? clienteIdInicial;

  const CrearPrestamoScreen({super.key, this.clienteIdInicial});

  @override
  ConsumerState<CrearPrestamoScreen> createState() => _CrearPrestamoScreenState();
}

class _CrearPrestamoScreenState extends ConsumerState<CrearPrestamoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _formatoFecha = DateFormat('dd/MM/yyyy');

  ClienteModel? _clienteSeleccionado;
  final _montoCtrl = TextEditingController();
  final _interesMensualCtrl = TextEditingController();
  final _interesTotalCtrl = TextEditingController();
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
    _montoCtrl.dispose();
    _interesMensualCtrl.dispose();
    _interesTotalCtrl.dispose();
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

      final repo = ref.read(prestamoRepositoryProvider);
      final numeroPrestamo = await repo.generarNumeroPrestamo(_clienteSeleccionado!.nombre);

      final storage = StorageService();
      final urlsFotos = <String>[];
      for (final bytes in _fotos) {
        urlsFotos.add(await storage.subirFoto(bytes: bytes, carpeta: 'prestamos'));
      }

      await repo.crear({
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
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo crear el préstamo: $e')));
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

    return Scaffold(
      appBar: AppBar(title: const Text('Crear Préstamo')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            clientesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, st) => Text('Error al cargar clientes: $e'),
              data: (clientes) {
                if (_clienteSeleccionado == null && widget.clienteIdInicial != null) {
                  final match = clientes.where((c) => c.id == widget.clienteIdInicial);
                  if (match.isNotEmpty) _clienteSeleccionado = match.first;
                }
                return DropdownButtonFormField<ClienteModel>(
                  initialValue: _clienteSeleccionado,
                  decoration: const InputDecoration(labelText: 'Cliente'),
                  isExpanded: true,
                  items: clientes
                      .map((c) => DropdownMenuItem(value: c, child: Text(c.nombre)))
                      .toList(),
                  onChanged: (v) => setState(() => _clienteSeleccionado = v),
                );
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _montoCtrl,
              decoration: const InputDecoration(labelText: 'Monto (L.)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              validator: (v) =>
                  (double.tryParse(v ?? '') ?? 0) > 0 ? null : 'Ingresá un monto válido',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cuotasCtrl,
              decoration: const InputDecoration(labelText: 'Número de cuotas'),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              validator: (v) => (int.tryParse(v ?? '') ?? 0) > 0 ? null : 'Ingresá las cuotas',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _plazo,
              decoration: const InputDecoration(labelText: 'Plazo'),
              items:
                  plazosDisponibles.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (v) => setState(() => _plazo = v ?? _plazo),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fecha de inicio'),
              subtitle: Text(_formatoFecha.format(_fechaInicio)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final f = await showDatePicker(
                  context: context,
                  initialDate: _fechaInicio,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (f != null) setState(() => _fechaInicio = f);
              },
            ),
            const Divider(height: 32),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Interés mensual %')),
                ButtonSegment(value: false, label: Text('Interés total fijo')),
              ],
              selected: {_usarInteresMensual},
              onSelectionChanged: (s) => setState(() => _usarInteresMensual = s.first),
            ),
            const SizedBox(height: 16),
            if (_usarInteresMensual)
              TextFormField(
                controller: _interesMensualCtrl,
                decoration: const InputDecoration(labelText: 'Porcentaje mensual (%)'),
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
            const SizedBox(height: 24),
            _seccionFotos(),
            const SizedBox(height: 24),
            _resumen(calculo),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Crear préstamo'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _seccionFotos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Fotos', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
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
        ),
      ],
    );
  }

  Widget _resumen(ResultadoCalculoPrestamo c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CEColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _filaResumen('Interés', formatearLempiras(c.interesCalculado)),
          _filaResumen('Total a pagar', formatearLempiras(c.totalAPagar)),
          _filaResumen('Cuota estimada', formatearLempiras(c.cuotaEstimada)),
        ],
      ),
    );
  }

  Widget _filaResumen(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(valor,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
