import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/pago_model.dart';
import '../../../../core/models/prestamo_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/cuotas_calculos.dart';
import '../../../../core/widgets/ce_scaffold.dart';
import '../../../../core/widgets/ce_section_card.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../prestamos/providers/prestamos_provider.dart';
import '../../data/recibo_pago_service.dart';
import '../../providers/pagos_provider.dart';

const _metodosPago = ['Efectivo', 'Transferencia'];

/// Pantalla "Cobrar": registra un abono repartido en cascada entre mora
/// y cuotas. La vista previa se recalcula localmente (sin pegarle a
/// Firestore) cada vez que cambia el monto, usando los pagos previos
/// que se traen una sola vez al entrar.
class CobrarScreen extends ConsumerStatefulWidget {
  final String prestamoId;
  final double? montoInicial;

  const CobrarScreen({super.key, required this.prestamoId, this.montoInicial});

  @override
  ConsumerState<CobrarScreen> createState() => _CobrarScreenState();
}

class _CobrarScreenState extends ConsumerState<CobrarScreen> {
  late final Stream<PrestamoModel?> _streamPrestamo =
      ref.read(prestamoRepositoryProvider).streamPorId(widget.prestamoId);

  final _montoCtrl = TextEditingController();
  final _lugarCtrl = TextEditingController();
  final _firmaCtrl = TextEditingController();
  String _metodoPago = 'Efectivo';
  bool _guardando = false;
  bool _prefilled = false;

  List<PagoModel>? _pagosPrevios;

  @override
  void initState() {
    super.initState();
    _cargarPagosPrevios();
  }

  Future<void> _cargarPagosPrevios() async {
    final pagos = await ref.read(pagoRepositoryProvider).obtenerPorPrestamo(widget.prestamoId);
    if (mounted) setState(() => _pagosPrevios = pagos);
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    _lugarCtrl.dispose();
    _firmaCtrl.dispose();
    super.dispose();
  }

  /// Igual que el flujo real de RegistrarPagoScreen.kt al terminar un
  /// abono: se muestra el recibo (con imprimir/compartir/descargar ya
  /// resuelto por la vista previa) y, apenas el usuario vuelve de verlo,
  /// se le pregunta si necesita otra copia -- si dice que si, se le
  /// vuelve a mostrar.
  Future<void> _imprimirConCopia(PagoModel pago) async {
    await ReciboPagoService.mostrarVistaPrevia(context, pago);
    if (!mounted) return;
    final quiereCopia = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Necesita otra copia?'),
        content: const Text('¿Querés ver/imprimir el recibo de nuevo?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí')),
        ],
      ),
    );
    if (quiereCopia == true) await _imprimirConCopia(pago);
  }

  void _prefillSiHaceFalta(PrestamoModel p) {
    if (_prefilled) return;
    _prefilled = true;
    _lugarCtrl.text = p.lugar;
    final usuario = ref.read(authProvider).usuario;
    _firmaCtrl.text = usuario?.nombre ?? '';
    if (widget.montoInicial != null && widget.montoInicial! > 0) {
      _montoCtrl.text = widget.montoInicial!.toStringAsFixed(2);
    }
  }

  Future<void> _guardar(PrestamoModel prestamo) async {
    final monto = double.tryParse(_montoCtrl.text) ?? 0;
    if (monto <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Ingresá un monto válido')));
      return;
    }

    setState(() => _guardando = true);
    try {
      final usuario = ref.read(authProvider).usuario!;
      final resultado = await ref.read(pagoRepositoryProvider).registrarPago(
            prestamo: prestamo,
            montoPagado: monto,
            metodoPago: _metodoPago,
            lugar: _lugarCtrl.text.trim(),
            firma: _firmaCtrl.text.trim(),
            registradoPor: usuario.uid,
            nombreCobrador: usuario.nombre,
          );

      if (!mounted) return;
      setState(() => _guardando = false);

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Pago registrado'),
          content: Text(
            resultado.distribucion.proximaCuotaPendiente != null
                ? 'Próxima cuota: #${resultado.distribucion.proximaCuotaPendiente} — '
                    '${DateFormat('dd/MM/yyyy').format(resultado.distribucion.fechaProximoPago!)}'
                : 'El préstamo quedó saldado.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // `this.context` (de CobrarScreen), no el del dialogo
                // que se acaba de cerrar -- la vista previa se abre
                // sobre la pantalla de atras, no dentro del dialogo.
                _imprimirConCopia(resultado.pago);
              },
              child: const Text('Imprimir recibo'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Listo'),
            ),
          ],
        ),
      );
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo registrar el pago: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PrestamoModel?>(
      stream: _streamPrestamo,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || _pagosPrevios == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final prestamo = snapshot.data;
        if (prestamo == null) {
          return const Scaffold(body: Center(child: Text('Préstamo no encontrado')));
        }
        _prefillSiHaceFalta(prestamo);
        return _contenido(context, prestamo, _pagosPrevios!);
      },
    );
  }

  Widget _contenido(BuildContext context, PrestamoModel prestamo, List<PagoModel> pagosPrevios) {
    final monto = double.tryParse(_montoCtrl.text) ?? 0;
    final distribucion = monto > 0
        ? distribuirPagoConMoraYCascada(
            prestamo: prestamo, pagosPrevios: pagosPrevios, montoPagado: monto)
        : null;

    return CeScaffold(
      maxWidth: 720,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Cobrar'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CeSectionCard(
            icono: Icons.person_outline,
            titulo: prestamo.cliente,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fila('Préstamo N°', prestamo.numeroPrestamo),
                _fila('Saldo actual', formatearLempiras(prestamo.saldo)),
                _fila('Cuota', formatearLempiras(prestamo.cuota)),
                if (prestamo.mora > 0) _fila('Mora aplicada', formatearLempiras(prestamo.mora)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          CeSectionCard(
            icono: Icons.payments_outlined,
            titulo: 'Monto del abono',
            child: Column(
              children: [
                TextFormField(
                  controller: _montoCtrl,
                  decoration: const InputDecoration(labelText: 'Monto (L.)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(
                            () => _montoCtrl.text = prestamo.cuota.toStringAsFixed(2)),
                        child: const Text('Una cuota'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setState(
                            () => _montoCtrl.text = prestamo.saldo.toStringAsFixed(2)),
                        child: const Text('Saldar todo'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          CeSectionCard(
            icono: Icons.notes_outlined,
            titulo: 'Detalles',
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _metodoPago,
                  decoration: const InputDecoration(labelText: 'Método de pago'),
                  items: _metodosPago.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (v) => setState(() => _metodoPago = v ?? _metodoPago),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lugarCtrl,
                  decoration: const InputDecoration(labelText: 'Lugar'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _firmaCtrl,
                  decoration: const InputDecoration(labelText: 'Firma / nombre cobrador'),
                ),
              ],
            ),
          ),
          if (distribucion != null) ...[
            const SizedBox(height: 16),
            _resumen(distribucion, prestamo),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _guardando ? null : () => _guardar(prestamo),
              style: ElevatedButton.styleFrom(shape: const StadiumBorder()),
              icon: _guardando
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check),
              label: const Text('Registrar pago'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _resumen(ResultadoDistribucion d, PrestamoModel prestamo) {
    final f = DateFormat('dd/MM/yyyy');
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: CEColors.primary, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.summarize_outlined, color: Colors.white70, size: 18),
              SizedBox(width: 8),
              Text('Vista previa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          if (d.moraAplicada > 0)
            _filaResumen('Mora', formatearLempiras(d.moraAplicada)),
          ...d.cuotasCubiertas.where((c) => c.numeroCuota > 0).map(
                (c) => _filaResumen(
                  'Cuota #${c.numeroCuota}${c.completada ? '' : ' (parcial)'}',
                  formatearLempiras(c.montoAplicado),
                ),
              ),
          const Divider(color: Colors.white24, height: 24),
          _filaResumen(
            d.proximaCuotaPendiente != null ? 'Próxima cuota' : 'Estado',
            d.proximaCuotaPendiente != null
                ? '#${d.proximaCuotaPendiente} — ${f.format(d.fechaProximoPago!)}'
                : 'SALDADO',
          ),
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
          Text(valor, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _fila(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: CEColors.textSecondary, fontSize: 13)),
          Text(valor, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
