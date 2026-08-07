import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/roles.dart';
import '../../../../core/models/prestamo_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/widgets/imagen_red_network.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/prestamos_provider.dart';

class PrestamoDetalleScreen extends ConsumerStatefulWidget {
  final String prestamoId;

  const PrestamoDetalleScreen({super.key, required this.prestamoId});

  @override
  ConsumerState<PrestamoDetalleScreen> createState() => _PrestamoDetalleScreenState();
}

class _PrestamoDetalleScreenState extends ConsumerState<PrestamoDetalleScreen> {
  PrestamoModel? _prestamo;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final p = await ref.read(prestamoRepositoryProvider).obtenerPorId(widget.prestamoId);
    if (mounted) {
      setState(() {
        _prestamo = p;
        _cargando = false;
      });
    }
  }

  Future<void> _eliminar() async {
    final usuario = ref.read(authProvider).usuario!;
    await ref.read(prestamoRepositoryProvider).marcarEliminado(
          widget.prestamoId,
          eliminadoPor: usuario.nombre,
        );
    await _cargar();
  }

  Future<void> _restaurar() async {
    await ref.read(prestamoRepositoryProvider).restaurar(widget.prestamoId);
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(authProvider).usuario;
    final esAdmin = usuario?.rol == Roles.admin;

    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final p = _prestamo;
    if (p == null) {
      return const Scaffold(body: Center(child: Text('Préstamo no encontrado')));
    }

    final formatoFecha = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text('N° ${p.numeroPrestamo}'),
        actions: [
          if (esAdmin)
            IconButton(
              icon: Icon(p.eliminado ? Icons.restore_from_trash_outlined : Icons.delete_outline),
              tooltip: p.eliminado ? 'Restaurar' : 'Eliminar',
              onPressed: p.eliminado ? _restaurar : _eliminar,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (p.eliminado)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CEColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('Eliminado por ${p.eliminadoPor ?? ''}',
                  style: const TextStyle(color: CEColors.danger)),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.cliente, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(p.estado.toUpperCase(),
                      style: const TextStyle(color: CEColors.textSecondary, fontSize: 12)),
                  const Divider(height: 24),
                  _fila('Monto', formatearLempiras(p.monto)),
                  _fila('Interés', formatearLempiras(p.interes)),
                  _fila('Total a pagar', formatearLempiras(p.totalPagar)),
                  _fila('Pagado', formatearLempiras(p.montoPagado)),
                  _fila('Saldo', formatearLempiras(p.saldo)),
                  _fila('Mora adeudada', formatearLempiras(p.mora)),
                  _fila('Cuota', formatearLempiras(p.cuota)),
                  _fila('Cuotas', '${p.cuotas}'),
                  _fila('Plazo', p.plazo),
                  if (p.fecha != null) _fila('Fecha inicio', formatoFecha.format(p.fecha!.toDate())),
                  _fila('Cobrador', p.cobrador),
                  _fila('Lugar', p.lugar),
                  if (p.garantia.isNotEmpty) _fila('Garantía', p.garantia),
                  if (p.observaciones.isNotEmpty) _fila('Observaciones', p.observaciones),
                ],
              ),
            ),
          ),
          if (p.fotos.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Fotos', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: p.fotos
                  .map((url) => ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 90,
                          height: 90,
                          child: ImagenRedNetwork(url: url),
                        ),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 24),
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
          Text(label, style: const TextStyle(color: CEColors.textSecondary)),
          Flexible(
            child: Text(valor, textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
