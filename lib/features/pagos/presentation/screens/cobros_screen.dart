import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../../../core/constants/roles.dart';
import '../../../../core/models/prestamo_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/contacto_utils.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/firestore_parse.dart';
import '../../../../core/utils/normalizar_texto.dart';
import '../../../../core/models/pago_model.dart';
import '../../../../core/utils/cuotas_calculos.dart';
import '../../../../core/utils/prestamo_calculos.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/ce_card.dart';
import '../../../../core/widgets/ce_data_table_style.dart';
import '../../../../core/widgets/ce_scaffold.dart';
import '../../../../core/widgets/ce_web_nav.dart';
import '../../../../core/widgets/pdf_preview_screen.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../clientes/providers/clientes_provider.dart';
import '../../../prestamos/presentation/screens/prestamo_detalle_screen.dart';
import '../../../prestamos/providers/prestamos_provider.dart';
import '../../data/reporte_cobros_pdf_service.dart';
import 'cobrar_screen.dart';
import 'ver_cuotas_screen.dart';
import '../../providers/cobros_cache.dart';
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

class NotifCobro {
  final PrestamoModel prestamo;
  final DateTime proximoPago;
  final DateTime? ultimoPago;
  final int diferenciaDias;
  final String tipo;
  final int cuotasCompletadas;

  const NotifCobro({
    required this.prestamo,
    required this.proximoPago,
    required this.ultimoPago,
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
  bool _refrescando = false;
  // TEMPORAL: para diagnosticar por que la Cloud Function no parece
  // acelerar nada en iOS Safari (reportado por el dueño) -- se saca en
  // cuanto se confirme la causa real.
  String? _debugOrigenCarga;
  // Se incrementa en cada _cargar(): un refresco que responde tarde
  // (llamado desde _irYRefrescar al volver de Pagar/Cuotas, por
  // ejemplo) ya no puede pisar el resultado de uno mas nuevo.
  int _cargaId = 0;
  List<NotifCobro> _notificaciones = [];
  final _busquedaCtrl = TextEditingController();
  String _filtroTipo = 'hoy';

  @override
  void initState() {
    super.initState();
    // Cache es SOLO para escritorio Web -- ver ClientesListScreen
    // (mismo patron). En mobile/Windows cada entrada arranca en
    // blanco y recalcula todo, como siempre.
    if (esEscritorioWeb(context)) {
      final cache = ref.read(cobrosCacheProvider);
      if (cache.tieneDatos) {
        _notificaciones = List.of(cache.notificaciones);
        _cargando = false;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  /// Detalle/Cobrar/Cuotas pueden terminar en un pago que salda el
  /// prestamo -- esta pantalla NO usa un stream en vivo (es un fetch
  /// puntual), asi que sin este refresco al volver se quedaba
  /// mostrando el mismo saldo/vencimiento de ANTES del pago (mas aun
  /// con las pestañas en memoria de escritorio Web, que no recargan
  /// solas al volver). Eso ya causo que un cobrador, al ver que
  /// "seguia pendiente", registrara el mismo pago dos veces.
  Future<void> _irYRefrescar(BuildContext context,
      {required String ruta, required Widget pantalla}) async {
    await irAPantalla(context, ruta: ruta, pantalla: pantalla);
    if (mounted) _cargar();
  }

  /// URL de la Cloud Function `obtenerDatosCobros` -- misma region que
  /// la base de Firestore (us-east1, confirmado via API; ver
  /// functions/index.js), no us-central1 (el default si no se
  /// especifica region al desplegar).
  static const _urlObtenerDatosCobros =
      'https://us-east1-capitalexpressapp-c03c5.cloudfunctions.net/obtenerDatosCobros';

  /// Trae prestamos+pagos para Cobros. Primero intenta la Cloud
  /// Function `obtenerDatosCobros` (agrupa las mismas consultas DENTRO
  /// del centro de datos de Google -- el celular paga un solo viaje
  /// largo en vez de varios); si no esta disponible (recien
  /// desplegada, sin conexion al endpoint, o Windows) cae SOLA al
  /// camino de siempre, con el mismo resultado final, solo mas lento.
  /// El calculo (fechas, mora, clasificacion) sigue siendo el mismo
  /// codigo Dart de abajo en los dos casos -- esto solo cambia DE
  /// DONDE vienen los documentos crudos.
  ///
  /// Se llama con `package:http` (peticion HTTP comun), NO con
  /// `FirebaseFunctions.instance.httpsCallable` -- ese paquete oficial
  /// de FlutterFire falla en Web (dart2js) con "Int64 accessor not
  /// supported", un bug conocido de esa libreria al armar la llamada
  /// (nada que ver con esta funcion ni con los datos que se mandan).
  /// Pedirselo a la funcion como una peticion HTTP cualquiera evita ese
  /// camino roto por completo -- funciona igual en Android/Web/Windows.
  ///
  /// Se manda el uid de QUIEN llama (nunca "esAdmin"/"cobradorUid: null"
  /// tal cual lo calcula este celular) porque esta app no usa Firebase
  /// Auth -- la funcion verifica el rol REAL contra el doc de
  /// `usuarios` antes de decidir si devuelve todo o solo lo de este
  /// cobrador, para que no baste con mandar un valor cualquiera desde
  /// afuera para llevarse los datos de todos los clientes.
  Future<(List<PrestamoModel>, Map<String, List<PagoModel>>)> _obtenerPrestamosYPagos({
    required bool esAdmin,
    required String? cobradorUid,
  }) async {
    final cronometro = Stopwatch()..start();
    try {
      final usuarioUid = ref.read(authProvider).usuario?.uid;
      final respuesta = await http
          .post(
            Uri.parse(_urlObtenerDatosCobros),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'data': {'usuarioUid': usuarioUid}
            }),
          )
          .timeout(const Duration(seconds: 15));

      final cuerpo = jsonDecode(respuesta.body) as Map<String, dynamic>;
      if (cuerpo['error'] != null) {
        throw Exception(cuerpo['error']);
      }
      final datos = cuerpo['result'] as Map<String, dynamic>;

      final prestamos = (datos['prestamos'] as List).map((p) {
        final mapa = Map<String, dynamic>.from(p as Map);
        return PrestamoModel.fromMap(mapa['id'] as String, mapa);
      }).toList();

      final pagosPorPrestamo = <String, List<PagoModel>>{};
      for (final p in (datos['pagos'] as List)) {
        final mapa = Map<String, dynamic>.from(p as Map);
        final pago = PagoModel.fromMap(mapa['id'] as String, mapa);
        (pagosPorPrestamo[pago.prestamoId] ??= []).add(pago);
      }
      _debugOrigenCarga = 'función (${cronometro.elapsedMilliseconds}ms)';
      return (prestamos, pagosPorPrestamo);
    } catch (e) {
      _debugOrigenCarga = 'directo -- función falló a los ${cronometro.elapsedMilliseconds}ms: $e';
      return _obtenerPrestamosYPagosDirecto(esAdmin: esAdmin, cobradorUid: cobradorUid);
    }
  }

  /// Camino de siempre (sin la Cloud Function): identico al que ya
  /// habia antes de agregar `_obtenerPrestamosYPagos`.
  Future<(List<PrestamoModel>, Map<String, List<PagoModel>>)> _obtenerPrestamosYPagosDirecto({
    required bool esAdmin,
    required String? cobradorUid,
  }) async {
    final prestamos = await ref
        .read(prestamoRepositoryProvider)
        .obtenerParaNotificaciones(cobradorUid: esAdmin ? null : cobradorUid);
    final candidatos =
        prestamos.where((p) => !_estadosExcluidos.contains(p.estado.toLowerCase())).toList();

    // UN SOLO pedido con TODOS los pagos de cada candidato: sirve para
    // la fecha de ultimo pago en pantalla Y para reconstruir la tabla
    // de cuotas completa (no solo `proximoPago`, que guarda unicamente
    // la cuota pendiente MAS ANTIGUA). Sin esto, un prestamo con varias
    // cuotas atrasadas seguidas -- comun en plazo Diario/Lunes a
    // Sabado -- se clasificaba siempre como "En mora" aunque HOY
    // tambien cayera una cuota pendiente, y el cobrador no lo veia
    // listado para visitar hoy.
    var pagosPorPrestamo = const <String, List<PagoModel>>{};
    try {
      pagosPorPrestamo =
          await ref.read(pagoRepositoryProvider).obtenerPorPrestamos(candidatos.map((p) => p.prestamoId).toList());
    } catch (_) {
      // sin conexion: se sigue con el respaldo de fecha de inicio / "Sin pagos aun".
    }
    return (candidatos, pagosPorPrestamo);
  }

  Future<void> _cargar() async {
    final miId = ++_cargaId;
    final usuario = ref.read(authProvider).usuario;
    final esAdmin = Roles.esAdminOEquivalente(usuario?.rol);
    // Solo en escritorio Web: si ya hay datos, el refresco pasa
    // calladito, sin spinner de pantalla completa. En mobile/Windows
    // siempre se muestra el spinner, como siempre. _refrescando en
    // cambio se prende SIEMPRE que haya una consulta en vuelo -- sin
    // esto, el refresco calladito de escritorio Web no daba ningun
    // indicio de que se estaba recargando.
    setState(() {
      if (!esEscritorioWeb(context) || _notificaciones.isEmpty) _cargando = true;
      _refrescando = true;
    });

    // Igual que procesarPrestamoUltraOptimizado en el sistema viejo: el
    // campo `proximoPago` del prestamo es la fuente principal, pero no
    // todos los prestamos (sobre todo los mas viejos) lo tienen bien
    // guardado. Cuando falta o no se puede interpretar, se reconstruye
    // en vivo: ultimo pago real + un intervalo de plazo, o si nunca pago,
    // fecha de inicio + un intervalo. Sin este respaldo, esos prestamos
    // simplemente desaparecian de Cobros/Notificaciones.
    final (candidatos, pagosPorPrestamo) =
        await _obtenerPrestamosYPagos(esAdmin: esAdmin, cobradorUid: usuario?.uid);

    final hoy = DateTime.now();
    final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
    final notificaciones = <NotifCobro>[];
    final fechasPorPrestamo = <String, DateTime?>{};

    final ultimosPagosTodos = <String, DateTime?>{
      for (final entry in pagosPorPrestamo.entries)
        entry.key: entry.value
            .map((p) => p.fechaPago?.toDate())
            .whereType<DateTime>()
            .fold<DateTime?>(null, (max, f) => max == null || f.isAfter(max) ? f : max),
    };

    for (final p in candidatos) {
      final directa = asProximoPagoFecha(p.proximoPago);
      if (directa != null) {
        fechasPorPrestamo[p.prestamoId] = directa;
      } else {
        final base = ultimosPagosTodos[p.prestamoId] ?? p.fecha?.toDate();
        fechasPorPrestamo[p.prestamoId] = base != null ? calcularProximaFecha(base, p.plazo) : null;
      }
    }

    for (final p in candidatos) {
      final fecha = fechasPorPrestamo[p.prestamoId];
      if (fecha == null) continue;

      final fechaSinHora = DateTime(fecha.year, fecha.month, fecha.day);
      var diferenciaDias = fechaSinHora.difference(hoySinHora).inDays;

      // Si el prestamo esta atrasado en la cuota mas antigua pero
      // igual tiene OTRA cuota pendiente cuyo vencimiento cae hoy
      // (arrastre de plazo Diario/Lunes a Sabado), cuenta como "Hoy"
      // -- el cobrador igual tiene que pasar hoy a cobrar, no solo
      // cuando esta al dia.
      if (diferenciaDias != 0 && p.fecha?.toDate() != null) {
        final cuotas = construirTablaCuotas(p, pagosPorPrestamo[p.prestamoId] ?? const []);
        final tieneCuotaHoy = cuotas.any((c) {
          if (c.estado == EstadoCuota.pagada) return false;
          final v = DateTime(c.fechaVencimiento.year, c.fechaVencimiento.month, c.fechaVencimiento.day);
          return v == hoySinHora;
        });
        if (tieneCuotaHoy) diferenciaDias = 0;
      }

      final tipo = diferenciaDias < 0
          ? 'vencido'
          : diferenciaDias == 0
              ? 'hoy'
              : diferenciaDias <= 3
                  ? 'proximo'
                  : 'futuro';

      final cuotasCompletadas =
          p.cuota > 0 ? (p.montoPagado / p.cuota).floor().clamp(0, p.cuotas) : 0;

      notificaciones.add(NotifCobro(
        prestamo: p,
        proximoPago: fecha,
        ultimoPago: ultimosPagosTodos[p.prestamoId],
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

    if (!mounted || miId != _cargaId) return; // una consulta mas nueva ya esta en curso/aplicada
    setState(() {
      _notificaciones = notificaciones;
      _cargando = false;
      _refrescando = false;
    });
    if (esEscritorioWeb(context)) {
      final cache = ref.read(cobrosCacheProvider);
      cache
        ..tieneDatos = true
        ..notificaciones = notificaciones;
    }
  }

  List<NotifCobro> get _filtradas {
    var lista = _notificaciones;
    if (_filtroTipo != 'Todos') {
      lista = lista.where((n) => n.tipo == _filtroTipo).toList();
    }
    final q = _busquedaCtrl.text;
    if (q.trim().isNotEmpty) {
      lista = lista.where((n) => coincideBusqueda(n.prestamo.cliente, q)).toList();
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
        'Estimado/a ${cliente.nombre}, le recordamos que tiene un pago pendiente con SIEG S. de R.L. de C.V. ¡Gracias!';
    await abrirWhatsapp(cliente.telefono, mensaje: mensaje);
  }

  Future<void> _aplicarMora(NotifCobro n) async {
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

  Future<void> _exportarPdf() async {
    final f = DateFormat('dd/MM/yyyy');
    final filas = _filtradas;
    final filtroTexto =
        'Filtro: ${_etiquetasTipo[_filtroTipo] ?? _filtroTipo} · ${filas.length} registros · '
        'Generado el ${f.format(DateTime.now())}';
    await abrirVistaPreviaPdf(
      context,
      titulo: 'Cobros — ${_etiquetasTipo[_filtroTipo] ?? _filtroTipo}',
      nombreArchivo: 'cobros.pdf',
      generar: () => ReporteCobrosPdfService.generarPendientes(
        filtroTexto: filtroTexto,
        filas: filas
            .map((n) => FilaCobroPendiente(
                  cliente: n.prestamo.cliente,
                  numeroPrestamo: n.prestamo.numeroPrestamo,
                  urgencia: _etiquetaUrgencia(n.diferenciaDias),
                  proximoPago: f.format(n.proximoPago),
                  ultimoPago: n.ultimoPago != null ? f.format(n.ultimoPago!) : 'Sin pagos aún',
                  cuota: n.prestamo.cuota,
                  mora: n.prestamo.mora,
                  cobrador: n.prestamo.cobrador,
                ))
            .toList(),
      ),
    );
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
    final esAdmin = Roles.esAdminOEquivalente(usuario?.rol);
    final filtradas = _cargando ? const <NotifCobro>[] : _filtradas;
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
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Exportar a PDF',
            onPressed: filtradas.isEmpty ? null : _exportarPdf,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Se ve SIEMPRE que haya una consulta en vuelo (incluso
                // el refresco calladito de escritorio Web) -- antes no
                // habia ningun indicio de que se estaba recargando.
                if (_refrescando)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                      child: LinearProgressIndicator(minHeight: 3),
                    ),
                  ),
                // TEMPORAL: ver comentario en _debugOrigenCarga.
                if (_debugOrigenCarga != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('Debug: $_debugOrigenCarga',
                        style: const TextStyle(fontSize: 10, color: CEColors.textSecondary)),
                  ),
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
                    onRefrescar: _cargar,
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
                        onTap: () => _irYRefrescar(context,
                            ruta: '/prestamos/${p.prestamoId}',
                            pantalla: PrestamoDetalleScreen(prestamoId: p.prestamoId, prestamoInicial: p)),
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
                            const SizedBox(height: 4),
                            Text(
                                n.ultimoPago != null
                                    ? 'Último pago: ${f.format(n.ultimoPago!)}'
                                    : 'Sin pagos aún',
                                style: const TextStyle(fontSize: 11, color: CEColors.textSecondary)),
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
                                      onPressed: () => _irYRefrescar(context,
                                          ruta: '/prestamos/${p.prestamoId}/cobrar',
                                          pantalla: CobrarScreen(prestamoId: p.prestamoId)),
                                      child: const Text('Pagar'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => _irYRefrescar(context,
                                          ruta: '/prestamos/${p.prestamoId}/cuotas',
                                          pantalla: VerCuotasScreen(prestamoId: p.prestamoId)),
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
  final List<NotifCobro> notificaciones;
  final bool esAdmin;
  final Color Function(int) colorUrgencia;
  final String Function(int) etiquetaUrgencia;
  final ValueChanged<PrestamoModel> onWhatsapp;
  final ValueChanged<NotifCobro> onAplicarMora;
  final VoidCallback onRefrescar;

  const _TablaCobros({
    required this.notificaciones,
    required this.esAdmin,
    required this.colorUrgencia,
    required this.etiquetaUrgencia,
    required this.onWhatsapp,
    required this.onAplicarMora,
    required this.onRefrescar,
  });

  @override
  Widget build(BuildContext context) {
    final f = DateFormat('dd/MM/yyyy');
    return CeDataTableCard(
      columns: const [
        DataColumn(label: Text('Cliente')),
        DataColumn(label: Text('N°')),
        DataColumn(label: Text('Saldo'), numeric: true),
        DataColumn(label: Text('Próxima cuota')),
        DataColumn(label: Text('Último pago')),
        DataColumn(label: Text('Estado')),
        DataColumn(label: Text('Cuota')),
        DataColumn(label: Text('Acciones')),
      ],
      rows: notificaciones.map((n) {
            final p = n.prestamo;
            final color = colorUrgencia(n.diferenciaDias);
            final mostrarAcciones = p.estado.toLowerCase() != 'inactivo';
            final puedeAplicarMora = n.diferenciaDias < 0 || p.mora > 0;
            return DataRow(
              onSelectChanged: (_) async {
                await irAPantalla(context,
                    ruta: '/prestamos/${p.prestamoId}',
                    pantalla: PrestamoDetalleScreen(prestamoId: p.prestamoId, prestamoInicial: p));
                onRefrescar();
              },
              cells: [
              DataCell(Text(p.cliente, style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text('#${p.numeroPrestamo}')),
              DataCell(Text(formatearLempiras(p.saldo),
                  style: const TextStyle(fontWeight: FontWeight.w700))),
              DataCell(Text(f.format(n.proximoPago),
                  style: TextStyle(color: color, fontWeight: FontWeight.w700))),
              DataCell(Text(n.ultimoPago != null ? f.format(n.ultimoPago!) : '—')),
              DataCell(ceTableBadge(etiquetaUrgencia(n.diferenciaDias), color)),
              DataCell(Text(p.cuotas > 0 ? '${n.cuotasCompletadas + 1} de ${p.cuotas}' : '—')),
              DataCell(mostrarAcciones
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () async {
                            await irAPantalla(context,
                                ruta: '/prestamos/${p.prestamoId}/cobrar',
                                pantalla: CobrarScreen(prestamoId: p.prestamoId));
                            onRefrescar();
                          },
                          child: const Text('Pagar'),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 18, color: CEColors.textSecondary),
                          onSelected: (accion) async {
                            switch (accion) {
                              case 'cuotas':
                                await irAPantalla(context,
                                    ruta: '/prestamos/${p.prestamoId}/cuotas',
                                    pantalla: VerCuotasScreen(prestamoId: p.prestamoId));
                                onRefrescar();
                                break;
                              case 'whatsapp':
                                onWhatsapp(p);
                                break;
                              case 'mora':
                                onAplicarMora(n);
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'cuotas',
                              child: ListTile(
                                leading: Icon(Icons.list_alt_outlined),
                                title: Text('Ver cuotas'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'whatsapp',
                              child: ListTile(
                                leading: Icon(Icons.chat_outlined, color: Color(0xFF25D366)),
                                title: Text('WhatsApp'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            if (esAdmin && puedeAplicarMora)
                              const PopupMenuItem(
                                value: 'mora',
                                child: ListTile(
                                  leading: Icon(Icons.warning_amber_outlined, color: CEColors.danger),
                                  title: Text('Aplicar mora'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                          ],
                        ),
                      ],
                    )
                  : const Text('—')),
            ]);
          }).toList(),
    );
  }
}
