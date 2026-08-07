import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/cliente_model.dart';
import '../../../../core/models/prestamo_model.dart';
import '../../../../core/models/usuario_simple.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/widgets/ce_card.dart';
import '../../../../core/widgets/ce_menu_card.dart';
import '../../../../core/widgets/ce_scaffold.dart';
import '../../../../core/widgets/ce_stat_card.dart';
import '../../../../core/widgets/imagen_red_network.dart';
import '../../../prestamos/providers/prestamos_provider.dart';
import '../../../usuarios/providers/usuarios_provider.dart';
import '../../providers/clientes_provider.dart';

/// Pantalla al tocar un cliente en la lista: resumen (no edicion directa)
/// con los totales de sus prestamos y accesos a Editar / Ver Detalles /
/// Asignar Cobrador / Eliminar.
class ClienteResumenScreen extends ConsumerStatefulWidget {
  final String clienteId;

  const ClienteResumenScreen({super.key, required this.clienteId});

  @override
  ConsumerState<ClienteResumenScreen> createState() => _ClienteResumenScreenState();
}

class _ClienteResumenScreenState extends ConsumerState<ClienteResumenScreen> {
  ClienteModel? _cliente;
  List<PrestamoModel> _prestamos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final cliente = await ref.read(clienteRepositoryProvider).obtenerPorId(widget.clienteId);
    final prestamos = await ref.read(prestamoRepositoryProvider).obtenerPorCliente(widget.clienteId);
    if (mounted) {
      setState(() {
        _cliente = cliente;
        _prestamos = prestamos;
        _cargando = false;
      });
    }
  }

  Future<void> _confirmarEliminar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar cliente'),
        content: Text('¿Eliminar a ${_cliente?.nombre}? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: CEColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(clienteRepositoryProvider).eliminar(widget.clienteId);
      if (mounted) context.pop();
    }
  }

  Future<void> _asignarCobrador() async {
    final cobradores = await ref.read(usuarioRepositoryProvider).obtenerCobradores();
    if (!mounted) return;
    final elegido = await showModalBottomSheet<UsuarioSimple>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Asignar cobrador', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            if (cobradores.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No hay cobradores registrados'),
              ),
            ...cobradores.map((c) => ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(c.nombre),
                  onTap: () => Navigator.pop(context, c),
                )),
          ],
        ),
      ),
    );

    if (elegido == null || !mounted) return;

    final clienteRepo = ref.read(clienteRepositoryProvider);
    final prestamoRepo = ref.read(prestamoRepositoryProvider);
    final actualizado = ClienteModel(
      id: _cliente!.id,
      nombre: _cliente!.nombre,
      identidad: _cliente!.identidad,
      telefono: _cliente!.telefono,
      direccionCasa: _cliente!.direccionCasa,
      direccionNegocio: _cliente!.direccionNegocio,
      estadoCivil: _cliente!.estadoCivil,
      nombreConyuge: _cliente!.nombreConyuge,
      identidadConyuge: _cliente!.identidadConyuge,
      telefonoConyuge: _cliente!.telefonoConyuge,
      referencia1Nombre: _cliente!.referencia1Nombre,
      referencia1Identidad: _cliente!.referencia1Identidad,
      referencia1Telefono: _cliente!.referencia1Telefono,
      referencia1Parentesco: _cliente!.referencia1Parentesco,
      referencia1Direccion: _cliente!.referencia1Direccion,
      referencia2Nombre: _cliente!.referencia2Nombre,
      referencia2Identidad: _cliente!.referencia2Identidad,
      referencia2Telefono: _cliente!.referencia2Telefono,
      referencia2Parentesco: _cliente!.referencia2Parentesco,
      referencia2Direccion: _cliente!.referencia2Direccion,
      fotoCasaUrl: _cliente!.fotoCasaUrl,
      fotoNegocioUrl: _cliente!.fotoNegocioUrl,
      fotoClienteUrl: _cliente!.fotoClienteUrl,
      fotoIdentidadFrenteUrl: _cliente!.fotoIdentidadFrenteUrl,
      fotoIdentidadReversoUrl: _cliente!.fotoIdentidadReversoUrl,
      fotoReciboLuzUrl: _cliente!.fotoReciboLuzUrl,
      garantiaTexto: _cliente!.garantiaTexto,
      garantiaFotoUrl: _cliente!.garantiaFotoUrl,
      estado: _cliente!.estado,
      tienePrestamo: _cliente!.tienePrestamo,
      cobradorAsignado: elegido.uid,
    );
    await clienteRepo.actualizar(actualizado);
    for (final p in _prestamos.where((p) => p.estado != 'saldado')) {
      await prestamoRepo.reasignarCobrador(p.prestamoId, elegido.uid);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cobrador asignado: ${elegido.nombre}')),
      );
      _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final c = _cliente;
    if (c == null) {
      return const Scaffold(body: Center(child: Text('Cliente no encontrado')));
    }

    double totalPrestado = 0, totalAbonado = 0, saldoPendiente = 0;
    var activos = 0, saldados = 0;
    for (final p in _prestamos) {
      final prestado = p.totalPagar > 0 ? p.totalPagar : (p.monto + p.interes);
      totalPrestado += prestado;
      totalAbonado += p.montoPagado;
      saldoPendiente += (prestado - p.montoPagado).clamp(0, double.infinity);
      if (p.estado == 'saldado') {
        saldados++;
      } else {
        activos++;
      }
    }

    return CeScaffold(
      maxWidth: 720,
      appBar: AppBar(title: const Text('Resumen del Cliente')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    width: 96,
                    height: 96,
                    child: c.fotoClienteUrl.isNotEmpty
                        ? ImagenRedNetwork(url: c.fotoClienteUrl)
                        : const ColoredBox(
                            color: CEColors.surface,
                            child: Icon(Icons.person_outline,
                                color: CEColors.textSecondary, size: 40),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(c.nombre,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
                if (c.telefono.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.call_outlined, size: 14, color: CEColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(c.telefono,
                          style: const TextStyle(color: CEColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.05,
            children: [
              CeStatCard(
                  icono: Icons.account_balance_outlined,
                  valor: formatearLempiras(totalPrestado),
                  etiqueta: 'Prestado'),
              CeStatCard(
                  icono: Icons.savings_outlined,
                  valor: formatearLempiras(totalAbonado),
                  etiqueta: 'Abonado',
                  color: CEColors.success),
              CeStatCard(
                  icono: Icons.warning_amber_outlined,
                  valor: formatearLempiras(saldoPendiente),
                  etiqueta: 'Pendiente',
                  color: CEColors.danger),
              CeStatCard(
                  icono: Icons.trending_up,
                  valor: '$activos',
                  etiqueta: 'Activos',
                  color: CEColors.accent),
              CeStatCard(
                  icono: Icons.check_circle_outline,
                  valor: '$saldados',
                  etiqueta: 'Saldados',
                  color: CEColors.success),
            ],
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              CeMenuCard(
                icono: Icons.edit_outlined,
                titulo: 'Editar',
                subtitulo: 'Datos del cliente',
                onTap: () async {
                  await context.push('/clientes/${c.id}/editar');
                  _cargar();
                },
              ),
              CeMenuCard(
                icono: Icons.badge_outlined,
                titulo: 'Ver Detalles',
                subtitulo: 'Datos completos',
                onTap: () => context.push('/clientes/${c.id}/detalle'),
              ),
              CeMenuCard(
                icono: Icons.person_pin_circle_outlined,
                titulo: 'Asignar Cobrador',
                subtitulo: c.cobradorAsignado.isEmpty ? 'Sin asignar' : 'Cambiar',
                onTap: _asignarCobrador,
              ),
              CeMenuCard(
                icono: Icons.delete_outline,
                titulo: 'Borrar Cliente',
                subtitulo: 'Acción permanente',
                onTap: _confirmarEliminar,
              ),
            ],
          ),
          if (_prestamos.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Préstamos', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 10),
            ..._prestamos.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: CeCard(
                    onTap: () => context.push('/prestamos/${p.prestamoId}'),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('N° ${p.numeroPrestamo}',
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(p.estado.toUpperCase(),
                                  style: const TextStyle(
                                      fontSize: 11, color: CEColors.textSecondary)),
                            ],
                          ),
                        ),
                        Text(formatearLempiras(p.saldo),
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(width: 6),
                        const Icon(Icons.chevron_right, color: CEColors.textSecondary),
                      ],
                    ),
                  ),
                )),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
