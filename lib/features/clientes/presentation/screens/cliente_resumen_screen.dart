import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/cliente_model.dart';
import '../../../../core/models/prestamo_model.dart';
import '../../../../core/models/usuario_simple.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/contacto_utils.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/reporte_clientes_calculos.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/ce_card.dart';
import '../../../../core/widgets/ce_menu_card.dart';
import '../../../../core/widgets/ce_scaffold.dart';
import '../../../../core/widgets/ce_stat_card.dart';
import '../../../../core/widgets/imagen_red_network.dart';
import '../../../../core/widgets/visor_foto_zoom.dart';
import '../../../prestamos/providers/prestamos_provider.dart';
import '../../../usuarios/providers/usuarios_provider.dart';
import '../../providers/clientes_provider.dart';

/// Pantalla al tocar un cliente en la lista: resumen (no edicion directa)
/// con los totales de sus prestamos y accesos a Editar / Ver Detalles /
/// Asignar Cobrador / Eliminar.
class ClienteResumenScreen extends ConsumerStatefulWidget {
  final String clienteId;
  final ClienteModel? clienteInicial;

  const ClienteResumenScreen({super.key, required this.clienteId, this.clienteInicial});

  @override
  ConsumerState<ClienteResumenScreen> createState() => _ClienteResumenScreenState();
}

class _ClienteResumenScreenState extends ConsumerState<ClienteResumenScreen> {
  // El cliente y sus prestamos quedan en vivo: si se aplica una mora, se
  // registra/borra un pago, o se reasigna el cobrador desde otro lado,
  // esta pantalla se actualiza sola. Los cobradores (para el selector de
  // "Asignar Cobrador") no hace falta que sean en vivo, son una lista de
  // staff que casi no cambia -- se cargan una sola vez.
  late final Stream<ClienteModel?> _streamCliente =
      ref.read(clienteRepositoryProvider).streamPorId(widget.clienteId);
  late final Stream<List<PrestamoModel>> _streamPrestamos =
      ref.read(prestamoRepositoryProvider).streamPorCliente(widget.clienteId);

  List<UsuarioSimple> _cobradores = [];

  @override
  void initState() {
    super.initState();
    _cargarCobradores();
  }

  Future<void> _cargarCobradores() async {
    final cobradores = await ref.read(cobradoresCacheProvider.future);
    if (mounted) setState(() => _cobradores = cobradores);
  }

  /// Nombre real del cobrador asignado (el campo del cliente solo
  /// guarda el uid) -- antes esto no se mostraba en ningun lado, solo
  /// se sabia si HABIA alguien asignado o no, no quien.
  String _nombreCobradorAsignado(ClienteModel c) {
    final uid = c.cobradorAsignado;
    if (uid.isEmpty) return 'Sin asignar';
    final match = _cobradores.where((co) => co.uid == uid);
    if (match.isEmpty) return 'Cobrador desconocido';
    return match.first.nombre;
  }

  Future<void> _confirmarEliminar(String nombre) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar cliente'),
        content: Text('¿Eliminar a $nombre? Esta acción no se puede deshacer.'),
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

  Future<void> _asignarCobrador(ClienteModel cliente, List<PrestamoModel> prestamos) async {
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
            if (_cobradores.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No hay cobradores registrados'),
              ),
            ..._cobradores.map((c) => ListTile(
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
    await clienteRepo.actualizarCobrador(cliente.id, elegido.uid);
    for (final p in prestamos.where((p) => p.estado != 'saldado')) {
      await prestamoRepo.reasignarCobrador(p.prestamoId, elegido.uid);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cobrador asignado: ${elegido.nombre}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ClienteModel?>(
      stream: _streamCliente,
      // Si ya veniamos de la lista/tile con el ClienteModel en mano, se
      // usa como dato inicial: la pantalla se ve completa en el primer
      // frame en vez de mostrar una ruedita mientras el stream conecta
      // (que casi siempre ya tenia el dato en la cache local igual).
      initialData: widget.clienteInicial,
      builder: (context, clienteSnap) {
        if (clienteSnap.connectionState == ConnectionState.waiting && !clienteSnap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (clienteSnap.hasError) {
          return Scaffold(
            body: Center(child: Text('Error al cargar el cliente: ${clienteSnap.error}')),
          );
        }
        final c = clienteSnap.data;
        if (c == null) {
          return const Scaffold(body: Center(child: Text('Cliente no encontrado')));
        }
        return StreamBuilder<List<PrestamoModel>>(
          stream: _streamPrestamos,
          builder: (context, prestamosSnap) {
            final prestamos = prestamosSnap.data ?? const [];
            return _contenido(context, c, prestamos);
          },
        );
      },
    );
  }

  Widget _contenido(BuildContext context, ClienteModel c, List<PrestamoModel> prestamos) {
    // Misma funcion que Reporte de Clientes / Reporte de Prestamos usan
    // para "pendiente" (el campo `saldo`, no un total-pagado recalculado)
    // -- para que el numero de "Pendiente" sea siempre el mismo sin
    // importar desde que pantalla se mire.
    final totales = totalesCliente(prestamos);
    final saldoPendiente = totales.pendiente;
    var activos = 0, saldados = 0;
    for (final p in prestamos) {
      if (p.estado == 'saldado') {
        saldados++;
      } else {
        activos++;
      }
    }

    final statItems = <CeStatItem>[
      CeStatItem(
          icono: Icons.account_balance_outlined,
          valor: formatearLempiras(totales.prestado),
          etiqueta: 'Prestado'),
      CeStatItem(
          icono: Icons.savings_outlined,
          valor: formatearLempiras(totales.abonado),
          etiqueta: 'Abonado',
          color: CEColors.success),
      CeStatItem(
          icono: Icons.account_balance_wallet_outlined,
          valor: formatearLempiras(totales.pendienteSinMora),
          etiqueta: 'Pendiente sin mora',
          color: CEColors.danger),
      if (totales.mora > 0) ...[
        CeStatItem(
            icono: Icons.report_gmailerrorred_outlined,
            valor: formatearLempiras(totales.mora),
            etiqueta: 'Mora',
            color: CEColors.danger),
        CeStatItem(
            icono: Icons.warning_amber_outlined,
            valor: formatearLempiras(saldoPendiente),
            etiqueta: 'Pendiente con mora',
            color: CEColors.danger),
      ],
      CeStatItem(
          icono: Icons.trending_up, valor: '$activos', etiqueta: 'Activos', color: CEColors.accent),
      CeStatItem(
          icono: Icons.check_circle_outline,
          valor: '$saldados',
          etiqueta: 'Saldados',
          color: CEColors.success),
    ];

    return CeScaffold(
      maxWidth: 720,
      appBar: AppBar(
        leading: const BackButton(),title: const Text('Resumen del Cliente')),
      body: esEscritorioWeb(context)
          ? _cuerpoEscritorio(context, c, prestamos, statItems)
          : _cuerpoMobile(context, c, prestamos, statItems),
    );
  }

  Widget _cuerpoMobile(
      BuildContext context, ClienteModel c, List<PrestamoModel> prestamos, List<CeStatItem> statItems) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _fotoYContacto(context, c),
        const SizedBox(height: 20),
        CeStatGrid(mobileCrossAxisCount: 3, mobileChildAspectRatio: 1.05, items: statItems),
        const SizedBox(height: 14),
        _filaCobrador(c, prestamos),
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
              onTap: () => context.push('/clientes/${c.id}/editar', extra: c),
            ),
            CeMenuCard(
              icono: Icons.badge_outlined,
              titulo: 'Ver Detalles',
              subtitulo: 'Datos completos',
              onTap: () => context.push('/clientes/${c.id}/detalle', extra: c),
            ),
            CeMenuCard(
              icono: Icons.delete_outline,
              titulo: 'Borrar Cliente',
              subtitulo: 'Acción permanente',
              onTap: () => _confirmarEliminar(c.nombre),
            ),
          ],
        ),
        if (prestamos.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text('Préstamos', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 10),
          ..._listaPrestamos(context, prestamos),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  /// Diseno de escritorio: dos columnas (panel de perfil angosto a la
  /// izquierda + totales/prestamos a la derecha) en vez de una sola
  /// columna centrada pensada para telefono -- ahi es donde las
  /// tarjetas de "Editar/Ver Detalles/Borrar" y las de totales se
  /// veian enormes e innecesarias en una pantalla ancha.
  Widget _cuerpoEscritorio(
      BuildContext context, ClienteModel c, List<PrestamoModel> prestamos, List<CeStatItem> statItems) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 300,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CeCard(child: _fotoYContacto(context, c)),
                const SizedBox(height: 14),
                _filaCobrador(c, prestamos),
                const SizedBox(height: 14),
                CeCard(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      _botonAccionEscritorio(
                        icono: Icons.edit_outlined,
                        texto: 'Editar',
                        onTap: () => context.push('/clientes/${c.id}/editar', extra: c),
                      ),
                      _botonAccionEscritorio(
                        icono: Icons.badge_outlined,
                        texto: 'Ver detalles',
                        onTap: () => context.push('/clientes/${c.id}/detalle', extra: c),
                      ),
                      _botonAccionEscritorio(
                        icono: Icons.delete_outline,
                        texto: 'Borrar cliente',
                        color: CEColors.danger,
                        onTap: () => _confirmarEliminar(c.nombre),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CeStatGrid(mobileCrossAxisCount: 3, mobileChildAspectRatio: 1.05, items: statItems),
                if (prestamos.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Préstamos', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 10),
                  ..._listaPrestamos(context, prestamos),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _botonAccionEscritorio({
    required IconData icono,
    required String texto,
    required VoidCallback onTap,
    Color color = CEColors.textPrimary,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            children: [
              Icon(icono, size: 17, color: color),
              const SizedBox(width: 12),
              Expanded(
                child:
                    Text(texto, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: color)),
              ),
              const Icon(Icons.chevron_right, size: 16, color: CEColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fotoYContacto(BuildContext context, ClienteModel c) {
    return Center(
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              width: 96,
              height: 96,
              child: c.fotoPersonaUrl.isNotEmpty
                  ? GestureDetector(
                      onTap: () => abrirFotoZoom(context, c.fotoPersonaUrl),
                      child: ImagenRedNetwork(url: c.fotoPersonaUrl),
                    )
                  : const ColoredBox(
                      color: CEColors.surface,
                      child: Icon(Icons.person_outline, color: CEColors.textSecondary, size: 40),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Text(c.nombre,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
          if (c.identidad.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(c.identidad, style: const TextStyle(color: CEColors.textSecondary, fontSize: 12)),
          ],
          if (c.telefono.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.call_outlined, size: 14, color: CEColors.textSecondary),
                const SizedBox(width: 4),
                Text(c.telefono, style: const TextStyle(color: CEColors.textSecondary, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: () => llamarTelefono(c.telefono),
                  icon: const Icon(Icons.call, size: 16),
                  label: const Text('Llamar'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF25D366),
                    side: const BorderSide(color: Color(0xFF25D366)),
                  ),
                  onPressed: () => abrirWhatsapp(c.telefono),
                  icon: const Icon(Icons.chat_outlined, size: 16),
                  label: const Text('WhatsApp'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _filaCobrador(ClienteModel c, List<PrestamoModel> prestamos) {
    return CeCard(
      onTap: () => _asignarCobrador(c, prestamos),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(color: CEColors.iconBadgeBg, shape: BoxShape.circle),
            child: const Icon(Icons.person_pin_circle_outlined, color: CEColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Cobrador Asignado',
                    style: TextStyle(fontSize: 11, color: CEColors.textSecondary)),
                const SizedBox(height: 2),
                Text(_nombreCobradorAsignado(c),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: CEColors.textSecondary),
        ],
      ),
    );
  }

  List<Widget> _listaPrestamos(BuildContext context, List<PrestamoModel> prestamos) {
    return prestamos
        .map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CeCard(
                onTap: () => context.push('/prestamos/${p.prestamoId}', extra: p),
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
                              style: const TextStyle(fontSize: 11, color: CEColors.textSecondary)),
                        ],
                      ),
                    ),
                    Text(formatearLempiras(p.saldo), style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right, color: CEColors.textSecondary),
                  ],
                ),
              ),
            ))
        .toList();
  }
}
