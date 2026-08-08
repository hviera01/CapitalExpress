import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/roles.dart';
import '../../../../core/models/prestamo_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/contacto_utils.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/firestore_parse.dart';
import '../../../../core/utils/normalizar_texto.dart';
import '../../../../core/utils/prestamo_calculos.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/ce_card.dart';
import '../../../../core/widgets/ce_data_table_style.dart';
import '../../../../core/widgets/ce_scaffold.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../clientes/providers/clientes_provider.dart';
import '../../../prestamos/providers/prestamos_provider.dart';
import '../../providers/pagos_provider.dart';

const _estadosExcluidos = {
  'saldado',
  'completado',
  'cancelado',
  'eliminado',
  'rechazado',
  'pendiente',
};

const _filtrosTipo = ['hoy', 'vencido', 'proximo', 'futuro', 'Todos'];
const _etiquetasTipo = {
  'Todos': 'Todos',
  'vencido': 'En mora',
  'hoy': 'Hoy',
  'proximo': 'Próximos',
  'futuro': 'Futuros',
};

class _NotifCobro {
  final PrestamoModel prestamo;
  final DateTime proximoPago;
  final int diferenciaDias;
  final String tipo;
  final int cuotasCompletadas;

  const _NotifCobro({
    required this.prestamo,
    required this.proximoPago,
    required this.diferenciaDias,
    required this.tipo,
    required this.cuotasCompletadas,
  });
}

/// Pantalla "Cobros" (renombrada de Notificaciones): cuotas vencidas y
/// proximas a vencer, calculadas en vivo sobre prestamos+pagos -- no
/// existe una coleccion `notificaciones` separada, igual que en la app
/// original.
class CobrosScreen extends ConsumerStatefulWidget {
  const CobrosScreen({super.key});

  @override
  ConsumerState<CobrosScreen> createState() => _CobrosScreenState();
}

class _CobrosScreenState extends ConsumerState<CobrosScreen> {
  bool _cargando = true;
  List<_NotifCobro> _notificaciones = [];
  final _busquedaCtrl = TextEditingController();
  String _filtroTipo = 'hoy';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final usuario = ref.read(authProvider).usuario;
    final esAdmin = usuario?.rol == Roles.admin;
    setState(() => _cargando = true);

    final prestamos = await ref
        .read(prestamoRepositoryProvider)
        .obtenerParaNotificaciones(cobradorUid: esAdmin ? null : usuario?.uid);

    final hoy = DateTime.now();
    final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
    final notificaciones = <_NotifCobro>[];

    // Igual que procesarPrestamoUltraOptimizado en el sistema viejo: el
    // campo `proximoPago` del prestamo es la fuente principal, pero no
    // todos los prestamos (sobre todo los mas viejos) lo tienen bien
    // guardado. Cuando falta o no se puede interpretar, se reconstruye
    // en vivo: ultimo pago real + un intervalo de plazo, o si nunca pago,
    // fecha de inicio + un intervalo. Sin este respaldo, esos prestamos
    // simplemente desaparecian de Cobros/Notificaciones.
    final candidatos = prestamos.where((p) => !_estadosExcluidos.contains(p.estado.toLowerCase())).toList();
    final pagoRepo = ref.read(pagoRepositoryProvider);
    final fechasPorPrestamo = <String, DateTime?>{};

    // Solo los que NO traen `proximoPago` bien guardado necesitan ir a
    // buscar su ultimo pago -- y eso se trae de a lotes (ver
    // obtenerUltimaFechaPorPrestamos), no uno por uno.
    final sinFechaDirecta = <PrestamoModel>[];
    for (final p in candidatos) {
      final directa = asProximoPagoFecha(p.proximoPago);
      if (directa != null) {
        fechasPorPrestamo[p.prestamoId] = directa;
      } else {
        sinFechaDirecta.add(p);
      }
    }

    var ultimasFechas = const <String, DateTime?>{};
    try {
      ultimasFechas = await pagoRepo
          .obtenerUltimaFechaPorPrestamos(sinFechaDirecta.map((p) => p.prestamoId).toList());
    } catch (_) {
      // sin conexion a pagos: se sigue con el respaldo de fecha de inicio.
    }

    for (final p in sinFechaDirecta) {
      final base = ultimasFechas[p.prestamoId] ?? p.fecha?.toDate();
      fechasPorPrestamo[p.prestamoId] = base != null ? calcularProximaFecha(base, p.plazo) : null;
    }

    for (final p in candidatos) {
      final fecha = fechasPorPrestamo[p.prestamoId];
      if (fecha == null) continue;

      final fechaSinHora = DateTime(fecha.year, fecha.month, fecha.day);
      final diferenciaDias = fechaSinHora.difference(hoySinHora).inDays;

      final tipo = diferenciaDias < 0
          ? 'vencido'
          : diferenciaDias == 0
              ? 'hoy'
              : diferenciaDias <= 3
                  ? 'proximo'
                  : 'futuro';

      final cuotasCompletadas =
          p.cuota > 0 ? (p.montoPagado / p.cuota).floor().clamp(0, p.cuotas) : 0;

      notificaciones.add(_NotifCobro(
        prestamo: p,
        proximoPago: fecha,
        diferenciaDias: diferenciaDias,
        tipo: tipo,
        cuotasCompletadas: cuotasCompletadas,
      ));
    }

    const prioridad = {'vencido': 0, 'hoy': 1, 'proximo': 2, 'futuro': 3};
    notificaciones.sort((a, b) {
      final p = (prioridad[a.tipo] ?? 9).compareTo(prioridad[b.tipo] ?? 9);
      if (p != 0) return p;
      return a.diferenciaDias.compareTo(b.diferenciaDias);
    });

    if (!mounted) return;
    setState(() {
      _notificaciones = notificaciones;
      _cargando = false;
    });
  }

  List<_NotifCobro> get _filtradas {
    var lista = _notificaciones;
    if (_filtroTipo != 'Todos') {
      lista = lista.where((n) => n.tipo == _filtroTipo).toList();
    }
    final q = normalizarTexto(_busquedaCtrl.text);
    if (q.isNotEmpty) {
      lista = lista.where((n) => normalizarTexto(n.prestamo.cliente).contains(q)).toList();
    }
    return lista;
  }

  Future<void> _enviarWhatsapp(PrestamoModel p) async {
    final cliente = await ref.read(clienteRepositoryProvider).obtenerPorId(p.clienteId);
    if (cliente == null || cliente.telefono.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('El cliente no tiene teléfono registrado')));
      }
      return;
    }
    final mensaje =
        'Estimado/a ${cliente.nombre}, le recordamos que tiene un pago pendiente con Capital Express. ¡Gracias!';
    await abrirWhatsapp(cliente.telefono, mensaje: mensaje);
  }

  Future<void> _aplicarMora(_NotifCobro n) async {
    final p = n.prestamo;
    final tieneMoraActiva = p.mora > 0;
    final cantidadMorasAplicadas = p.morasAplicadas.length;
    final diasParaMora = tieneMoraActiva && p.fechaUltimaMora != null
        ? DateTime.now().difference(p.fechaUltimaMora!.toDate()).inDays.clamp(0, 9999)
        : (-n.diferenciaDias).clamp(1, 9999);
    final totalPagarOriginal = p.totalPagar > 0 ? p.totalPagar : (p.monto + p.interes);
    final moraSugerida = totalPagarOriginal * 0.005 * diasParaMora;

    final montoCtrl = TextEditingController(text: moraSugerida.toStringAsFixed(2));

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aplicar Mora'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(cantidadMorasAplicadas > 0
                ? 'Días desde la última mora: $diasParaMora'
                : 'Días vencido: $diasParaMora'),
            const SizedBox(height: 4),
            Text('Sugerido: 0.5% × ${formatearLempiras(totalPagarOriginal)} × $diasParaMora días',
                style: const TextStyle(fontSize: 12, color: CEColors.textSecondary)),
            const SizedBox(height: 16),
            TextField(
              controller: montoCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Monto de la mora (L.)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Aplicar', style: TextStyle(color: CEColors.danger)),
          ),
        ],
      ),
    );

    if (confirmado != true) return;
    final monto = double.tryParse(montoCtrl.text) ?? moraSugerida;
    final usuario = ref.read(authProvider).usuario!;
    await ref.read(prestamoRepositoryProvider).aplicarMora(
          p.prestamoId,
          monto: monto,
          aplicadaPor: usuario.nombre,
          saldoActual: p.saldo,
        );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Mora aplicada: ${formatearLempiras(monto)}')));
      _cargar();
    }
  }

  Color _colorUrgencia(int diferenciaDias) {
    if (diferenciaDias < -3) return CEColors.danger;
    if (diferenciaDias < 0) return const Color(0xFFEA580C);
    if (diferenciaDias == 0) return CEColors.warning;
    if (diferenciaDias <= 3) return CEColors.success;
    return CEColors.textSecondary;
  }

  // Mismo badge de dias que UrgenciaStyle en NotificacionesScreen.kt:
  // "Xd" (dias de atraso/faltantes), "Hoy" cuando cae justo hoy.
  String _etiquetaDias(int diferenciaDias) {
    if (diferenciaDias == 0) return 'Hoy';
    if (diferenciaDias < 0) return '${-diferenciaDias}d';
    return '${diferenciaDias}d';
  }

  String _etiquetaUrgencia(int diferenciaDias) {
    if (diferenciaDias < -3) return 'EN MORA';
    if (diferenciaDias < 0) return 'VENCIDO';
    if (diferenciaDias == 0) return 'HOY';
    if (diferenciaDias <= 3) return 'PRÓXIMO';
    return 'PENDIENTE';
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(authProvider).usuario;
    final esAdmin = usuario?.rol == Roles.admin;
    final filtradas = _cargando ? const <_NotifCobro>[] : _filtradas;
    final total = filtradas.length;
    final mora = filtradas.where((n) => n.tipo == 'vencido').length;
    final hoyCount = filtradas.where((n) => n.tipo == 'hoy').length;
    final proximos = filtradas.where((n) => n.tipo == 'proximo').length;
    final f = DateFormat('dd/MM/yyyy');

    return CeScaffold(
      maxWidth: 900,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Cobros'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar)],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _busquedaCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar cliente',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(_busquedaCtrl.clear),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _statChip('Total', '$total'),
                    _statChip('Mora', '$mora', color: CEColors.danger),
                    _statChip('Hoy', '$hoyCount', color: CEColors.warning),
                    _statChip('Próximos', '$proximos', color: CEColors.success),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _filtrosTipo
                      .map((t) => ChoiceChip(
                            label: Text(_etiquetasTipo[t] ?? t),
                            selected: _filtroTipo == t,
                            onSelected: (_) => setState(() => _filtroTipo = t),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                if (filtradas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 24),
                    child: Center(child: Text('No hay cobros con este filtro')),
                  )
                else if (esEscritorioWeb(context))
                  _TablaCobros(
                    notificaciones: filtradas,
                    esAdmin: esAdmin,
                    colorUrgencia: _colorUrgencia,
                    etiquetaUrgencia: _etiquetaUrgencia,
                    onWhatsapp: _enviarWhatsapp,
                    onAplicarMora: _aplicarMora,
                  )
                else
                  ...filtradas.map((n) {
                    final p = n.prestamo;
                    final color = _colorUrgencia(n.diferenciaDias);
                    final progreso =
                        p.cuotas > 0 ? (n.cuotasCompletadas / p.cuotas).clamp(0.0, 1.0) : 0.0;
                    final mostrarAcciones = p.estado.toLowerCase() != 'inactivo';
                    final puedeAplicarMora = n.diferenciaDias < 0 || p.mora > 0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: CeCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p.cliente,
                                          style: const TextStyle(fontWeight: FontWeight.w700)),
                                      Text('N° ${p.numeroPrestamo}',
                                          style: const TextStyle(
                                              fontSize: 11, color: CEColors.textSecondary)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(_etiquetaUrgencia(n.diferenciaDias),
                                          style: TextStyle(
                                              fontSize: 10, color: color, fontWeight: FontWeight.w800)),
                                      const SizedBox(width: 4),
                                      Text(_etiquetaDias(n.diferenciaDias),
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: color.withValues(alpha: 0.8),
                                              fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Saldo pendiente',
                                        style: TextStyle(fontSize: 11, color: CEColors.textSecondary)),
                                    const SizedBox(height: 2),
                                    Text(formatearLempiras(p.saldo),
                                        style:
                                            const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('Próxima cuota',
                                        style: TextStyle(fontSize: 11, color: CEColors.textSecondary)),
                                    const SizedBox(height: 2),
                                    Text(f.format(n.proximoPago),
                                        style: TextStyle(
                                            fontSize: 13, fontWeight: FontWeight.w700, color: color)),
                                  ],
                                ),
                              ],
                            ),
                            if (p.cuotas > 0) ...[
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progreso,
                                  minHeight: 6,
                                  backgroundColor: CEColors.border,
                                  color: CEColors.accent,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text('Cuota ${n.cuotasCompletadas + 1} de ${p.cuotas}',
                                  style: const TextStyle(fontSize: 11, color: CEColors.textSecondary)),
                            ],
                            if (mostrarAcciones) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () =>
                                          context.push('/prestamos/${p.prestamoId}/cobrar'),
                                      child: const Text('Pagar'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () =>
                                          context.push('/prestamos/${p.prestamoId}/cuotas'),
                                      child: const Text('Cuotas'),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chat_outlined, color: Color(0xFF25D366)),
                                    tooltip: 'WhatsApp',
                                    onPressed: () => _enviarWhatsapp(p),
                                  ),
                                  if (esAdmin && puedeAplicarMora)
                                    IconButton(
                                      icon: const Icon(Icons.warning_amber_outlined,
                                          color: CEColors.danger),
                                      tooltip: 'Aplicar Mora',
                                      onPressed: () => _aplicarMora(n),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );
  }

  Widget _statChip(String label, String valor, {Color color = CEColors.primary}) {
    return Expanded(
      child: Column(
        children: [
          Text(valor, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: CEColors.textSecondary)),
        ],
      ),
    );
  }
}

/// Version tabla de Cobros, solo para escritorio Web (ver
/// esEscritorioWeb).
class _TablaCobros extends StatelessWidget {
  final List<_NotifCobro> notificaciones;
  final bool esAdmin;
  final Color Function(int) colorUrgencia;
  final String Function(int) etiquetaUrgencia;
  final ValueChanged<PrestamoModel> onWhatsapp;
  final ValueChanged<_NotifCobro> onAplicarMora;

  const _TablaCobros({
    required this.notificaciones,
    required this.esAdmin,
    required this.colorUrgencia,
    required this.etiquetaUrgencia,
    required this.onWhatsapp,
    required this.onAplicarMora,
  });

  @override
  Widget build(BuildContext context) {
    final f = DateFormat('dd/MM/yyyy');
    return CeCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: ceTableHeadingRowColor,
          headingTextStyle: ceTableHeadingTextStyle,
          columns: const [
            DataColumn(label: Text('Cliente')),
            DataColumn(label: Text('N°')),
            DataColumn(label: Text('Saldo'), numeric: true),
            DataColumn(label: Text('Próxima cuota')),
            DataColumn(label: Text('Estado')),
            DataColumn(label: Text('Cuota')),
            DataColumn(label: Text('Acciones')),
          ],
          rows: notificaciones.map((n) {
            final p = n.prestamo;
            final color = colorUrgencia(n.diferenciaDias);
            final mostrarAcciones = p.estado.toLowerCase() != 'inactivo';
            final puedeAplicarMora = n.diferenciaDias < 0 || p.mora > 0;
            return DataRow(cells: [
              DataCell(Text(p.cliente, style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text('#${p.numeroPrestamo}')),
              DataCell(Text(formatearLempiras(p.saldo),
                  style: const TextStyle(fontWeight: FontWeight.w700))),
              DataCell(Text(f.format(n.proximoPago),
                  style: TextStyle(color: color, fontWeight: FontWeight.w700))),
              DataCell(ceTableBadge(etiquetaUrgencia(n.diferenciaDias), color)),
              DataCell(Text(p.cuotas > 0 ? '${n.cuotasCompletadas + 1} de ${p.cuotas}' : '—')),
              DataCell(mostrarAcciones
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () => context.push('/prestamos/${p.prestamoId}/cobrar'),
                          child: const Text('Pagar'),
                        ),
                        TextButton(
                          onPressed: () => context.push('/prestamos/${p.prestamoId}/cuotas'),
                          child: const Text('Cuotas'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chat_outlined, size: 18, color: Color(0xFF25D366)),
                          tooltip: 'WhatsApp',
                          onPressed: () => onWhatsapp(p),
                        ),
                        if (esAdmin && puedeAplicarMora)
                          IconButton(
                            icon: const Icon(Icons.warning_amber_outlined,
                                size: 18, color: CEColors.danger),
                            tooltip: 'Aplicar Mora',
                            onPressed: () => onAplicarMora(n),
                          ),
                      ],
                    )
                  : const Text('—')),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}
