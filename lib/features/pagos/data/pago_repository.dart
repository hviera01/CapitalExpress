import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/pago_model.dart';
import '../../../core/models/prestamo_model.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/cuotas_calculos.dart';
import '../../bitacora/data/bitacora_repository.dart';

class PagoRegistrado {
  final PagoModel pago;
  final ResultadoDistribucion distribucion;

  const PagoRegistrado({required this.pago, required this.distribucion});
}

class PagoRepository {
  final _col = FirebaseFirestore.instance.collection('pagos');

  Query<Map<String, dynamic>> _conRango({DateTime? inicio, DateTime? fin, String? cobradorUid}) {
    Query<Map<String, dynamic>> query = _col;
    if (inicio != null) {
      query = query.where('fechaPago', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio));
    }
    if (fin != null) {
      final finInclusive = DateTime(fin.year, fin.month, fin.day, 23, 59, 59);
      query = query.where('fechaPago', isLessThanOrEqualTo: Timestamp.fromDate(finInclusive));
    }
    if (cobradorUid != null) {
      query = query.where('registradoPor', isEqualTo: cobradorUid);
    }
    return query;
  }

  /// Los ultimos pagos registrados (Panel Admin/Cobrador: "Actividad
  /// reciente"), sin importar la fecha.
  Future<List<PagoModel>> obtenerRecientes({int limite = 6, String? cobradorUid}) async {
    Query<Map<String, dynamic>> query = _col;
    if (cobradorUid != null) {
      query = query.where('registradoPor', isEqualTo: cobradorUid);
    }
    query = query.orderBy('fechaPago', descending: true).limit(limite);
    final snap = await query.get();
    final pagos = <PagoModel>[];
    for (final doc in snap.docs) {
      try {
        pagos.add(PagoModel.fromDoc(doc));
      } catch (_) {
        // documento con formato inesperado: se omite.
      }
    }
    return pagos;
  }

  /// Pagos en un rango de fechas (Dashboard, Reporte de Cobros). Sin
  /// rango trae los ultimos 200 para no descargar el historico entero.
  Future<List<PagoModel>> obtenerConRango({
    DateTime? inicio,
    DateTime? fin,
    String? cobradorUid,
  }) async {
    var query = _conRango(inicio: inicio, fin: fin, cobradorUid: cobradorUid);
    if (inicio == null && fin == null) {
      query = query.orderBy('fechaPago', descending: true).limit(200);
    }
    final snap = await query.get();
    final pagos = <PagoModel>[];
    for (final doc in snap.docs) {
      try {
        pagos.add(PagoModel.fromDoc(doc));
      } catch (_) {
        // documento con formato inesperado: se omite.
      }
    }
    pagos.sort((a, b) => (b.fechaPago?.compareTo(a.fechaPago ?? b.fechaPago!) ?? 0));
    return pagos;
  }

  Future<List<PagoModel>> obtenerPorPrestamo(String prestamoId) async {
    final snap = await _col.where('prestamoId', isEqualTo: prestamoId).get();
    return _ordenados(snap.docs);
  }

  /// Fecha del ULTIMO pago de cada prestamo en [prestamoIds] (o sin
  /// entrada si no tiene pagos) -- para Cobros/Notificaciones, que
  /// necesita reconstruir el proximo pago cuando el prestamo no tiene
  /// bien guardado el campo `proximoPago` (sobre todo prestamos
  /// viejos). Antes se hacia con una consulta POR PRESTAMO
  /// (`obtenerPorPrestamo` uno por uno) -- con cientos de prestamos sin
  /// ese campo, eso eran cientos de viajes de red separados y la
  /// pantalla se sentia eterna. Ahora se trae todo en lotes de 10 con
  /// `whereIn` (limite de Firestore), en paralelo.
  Future<Map<String, DateTime?>> obtenerUltimaFechaPorPrestamos(List<String> prestamoIds) async {
    final resultado = <String, DateTime?>{};
    if (prestamoIds.isEmpty) return resultado;

    final lotes = <List<String>>[];
    for (var i = 0; i < prestamoIds.length; i += 10) {
      lotes.add(prestamoIds.sublist(i, (i + 10).clamp(0, prestamoIds.length)));
    }

    final snaps = await Future.wait(
      lotes.map((lote) => _col.where('prestamoId', whereIn: lote).get()),
    );

    for (final snap in snaps) {
      for (final doc in snap.docs) {
        try {
          final pago = PagoModel.fromDoc(doc);
          final f = pago.fechaPago?.toDate();
          if (f == null) continue;
          final actual = resultado[pago.prestamoId];
          if (actual == null || f.isAfter(actual)) {
            resultado[pago.prestamoId] = f;
          }
        } catch (_) {
          // documento con formato inesperado: se omite.
        }
      }
    }
    return resultado;
  }

  /// Igual que [obtenerPorPrestamo] pero en vivo (Historial de Pagos de
  /// un prestamo puntual) -- si se registra o borra un pago desde otra
  /// pantalla/dispositivo, esta lista se actualiza sola.
  Stream<List<PagoModel>> streamPorPrestamo(String prestamoId) {
    return _col
        .where('prestamoId', isEqualTo: prestamoId)
        .snapshots()
        .map((snap) => _ordenados(snap.docs));
  }

  List<PagoModel> _ordenados(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final pagos = <PagoModel>[];
    for (final doc in docs) {
      try {
        pagos.add(PagoModel.fromDoc(doc));
      } catch (_) {
        // documento con formato inesperado: se omite.
      }
    }
    pagos.sort((a, b) => (b.fechaPago?.compareTo(a.fechaPago ?? b.fechaPago!) ?? 0));
    return pagos;
  }

  /// Borra un pago Y recalcula el prestamo (montoPagado/saldo/estado)
  /// desde cero a partir de los pagos que quedan, en vez de "revertir"
  /// con una resta puntual -- mismo criterio "recalcular desde la
  /// fuente" que usa registrarPago, para no acumular errores de
  /// redondeo/estados intermedios. OJO: `mora` (el doc del prestamo) es
  /// un total HISTORICO de mora aplicada, no se toca al borrar un pago
  /// -- la mora pendiente ya se deriva solita de `mora - suma(pagos
  /// restantes .mora)`, restando el pago borrado de esa suma alcanza.
  /// Excepcion: si el prestamo ya estaba "saldado" ese historico se
  /// habia puesto en 0 -- no se puede reconstruir exactamente, queda en
  /// 0 (limitacion conocida, caso raro: borrar el pago que saldo todo).
  Future<void> eliminarConReversion(
    PagoModel pago, {
    required String usuarioUid,
    required String usuarioNombre,
  }) async {
    final db = FirebaseFirestore.instance;
    final prestamoRef = db.collection('prestamos').doc(pago.prestamoId);

    await _col.doc(pago.docId).delete();
    BitacoraRepository().registrar(
      accion: 'eliminar_pago',
      entidadTipo: 'pago',
      descripcion:
          'Pago de ${formatearLempiras(pago.total)} - ${pago.clienteNombre} (N° ${pago.numeroPrestamo})',
      usuarioUid: usuarioUid,
      usuarioNombre: usuarioNombre,
    );

    final prestamoSnap = await prestamoRef.get();
    if (!prestamoSnap.exists) return;
    final d = prestamoSnap.data()!;
    final totalPagar = (d['totalPagar'] as num?)?.toDouble() ?? 0.0;
    final moraHistorica = (d['mora'] as num?)?.toDouble() ?? 0.0;

    final restantes = await obtenerPorPrestamo(pago.prestamoId);
    final totalCuotasPagadas = restantes.fold<double>(0, (a, p) => a + p.monto);
    final totalMoraPagada = restantes.fold<double>(0, (a, p) => a + p.mora);
    final moraPendiente = (moraHistorica - totalMoraPagada).clamp(0, double.infinity);

    final nuevoSaldo = (totalPagar - totalCuotasPagadas + moraPendiente).clamp(0, double.infinity);
    final nuevoMontoPagado = totalCuotasPagadas + totalMoraPagada;
    final nuevoEstado =
        nuevoSaldo <= 0.01 ? 'saldado' : (moraPendiente > 0.01 ? 'mora' : 'activo');

    await prestamoRef.update({
      'montoPagado': nuevoMontoPagado,
      'saldo': nuevoSaldo,
      'estado': nuevoEstado,
      'fechaUltimaActualizacion': Timestamp.now(),
    });
  }

  /// Registra un abono: reparte el monto entre mora y cuotas (cascada),
  /// guarda el doc en `pagos`, y actualiza el prestamo -- mismo
  /// algoritmo y formulas que RegistrarPagoScreen.kt (ver
  /// core/utils/cuotas_calculos.dart para el detalle de cada formula).
  /// Devuelve el pago ya guardado (para poder imprimir el recibo sin
  /// otra lectura) junto con el detalle de la distribucion.
  Future<PagoRegistrado> registrarPago({
    required PrestamoModel prestamo,
    required double montoPagado,
    required String metodoPago,
    required String lugar,
    required String firma,
    required String registradoPor,
    required String nombreCobrador,
  }) async {
    final db = FirebaseFirestore.instance;
    final prestamoRef = db.collection('prestamos').doc(prestamo.prestamoId);

    final pagosPrevios = await obtenerPorPrestamo(prestamo.prestamoId);
    final distribucion = distribuirPagoConMoraYCascada(
      prestamo: prestamo,
      pagosPrevios: pagosPrevios,
      montoPagado: montoPagado,
    );

    final totalCuotasYaPagadas = pagosPrevios.fold<double>(0, (a, p) => a + p.monto);
    final totalMoraYaPagada = pagosPrevios.fold<double>(0, (a, p) => a + p.mora);
    final totalRealmentePagado = totalCuotasYaPagadas + totalMoraYaPagada;

    final totalPagar = prestamo.totalPagar > 0 ? prestamo.totalPagar : (prestamo.monto + prestamo.interes);
    final nuevoMontoPagado = totalRealmentePagado + montoPagado;
    final moraYaPagadaTotal = totalMoraYaPagada + distribucion.moraAplicada;
    final moraNuevamentePendiente =
        (distribucion.moraHistoricaCorregida - moraYaPagadaTotal).clamp(0.0, double.infinity);
    final cuotasAcumuladas = totalCuotasYaPagadas + distribucion.montoPagoNormal;
    final nuevoSaldo =
        (totalPagar - cuotasAcumuladas + moraNuevamentePendiente).clamp(0.0, double.infinity);

    final moraCubierta = distribucion.cuotasCubiertas.where((c) => c.numeroCuota == 0);
    final nuevoEstado = nuevoSaldo <= 0.01
        ? 'saldado'
        : (moraCubierta.isNotEmpty && !moraCubierta.first.completada ? 'mora' : 'activo');

    final ahora = Timestamp.now();
    final descripcion = _descripcionPago(distribucion);

    final pagoRef = _col.doc();
    await pagoRef.set({
      'clienteId': prestamo.clienteId,
      'clienteNombre': prestamo.cliente,
      'prestamoId': prestamo.prestamoId,
      'numeroPrestamo': prestamo.numeroPrestamo,
      'monto': distribucion.montoPagoNormal,
      'mora': distribucion.moraAplicada,
      'fechaPago': ahora,
      'registradoPor': registradoPor,
      'nombreCobrador': nombreCobrador,
      'saldoRestante': nuevoSaldo,
      'lugar': lugar,
      'firma': firma,
      'metodoPago': metodoPago,
      'plazo': prestamo.plazo,
      'proximaFechaProgramada': distribucion.fechaProximoPago != null
          ? Timestamp.fromDate(distribucion.fechaProximoPago!)
          : null,
      'totalCuotasCompletas': distribucion.totalCuotasCompletas,
      'cuotasCubiertas':
          distribucion.cuotasCubiertas.where((c) => c.numeroCuota > 0).map((c) => c.toMap()).toList(),
      'descripcionCuotas': descripcion,
      'sistemaPagoEnCascada': true,
    });

    final actualizacionPrestamo = <String, dynamic>{
      'saldo': nuevoSaldo,
      'montoPagado': nuevoMontoPagado,
      'proximoPago': distribucion.fechaProximoPago != null
          ? Timestamp.fromDate(distribucion.fechaProximoPago!)
          : 'saldado',
      'estado': nuevoEstado,
      'fechaUltimaActualizacion': ahora,
      'mora': distribucion.moraHistoricaCorregida,
    };
    if (nuevoSaldo <= 0.01) {
      actualizacionPrestamo['fechaSaldado'] = ahora;
      actualizacionPrestamo['fechaCancelacion'] = ahora;
      actualizacionPrestamo['mora'] = 0.0;
    }
    await prestamoRef.update(actualizacionPrestamo);

    // Best-effort, igual que el runCatching del Kotlin original: si esto
    // falla no debe tumbar el pago que ya se guardo.
    try {
      await db.collection('clientes').doc(prestamo.clienteId).update({
        'ultimaActividad': ahora,
        'fechaUltimaActualizacion': ahora,
      });
    } catch (_) {}

    final pagoGuardado = PagoModel(
      docId: pagoRef.id,
      clienteId: prestamo.clienteId,
      clienteNombre: prestamo.cliente,
      prestamoId: prestamo.prestamoId,
      numeroPrestamo: prestamo.numeroPrestamo,
      monto: distribucion.montoPagoNormal,
      mora: distribucion.moraAplicada,
      fechaPago: ahora,
      registradoPor: registradoPor,
      nombreCobrador: nombreCobrador,
      saldoRestante: nuevoSaldo,
      lugar: lugar,
      firma: firma,
      metodoPago: metodoPago,
      plazo: prestamo.plazo,
      proximaFechaProgramada:
          distribucion.fechaProximoPago != null ? Timestamp.fromDate(distribucion.fechaProximoPago!) : null,
      totalCuotasCompletas: distribucion.totalCuotasCompletas,
      descripcionCuotas: descripcion,
      sistemaPagoEnCascada: true,
      cuotasCubiertas: distribucion.cuotasCubiertas.where((c) => c.numeroCuota > 0).toList(),
    );

    return PagoRegistrado(pago: pagoGuardado, distribucion: distribucion);
  }

  String _descripcionPago(ResultadoDistribucion d) {
    final partes = <String>[];
    for (final c in d.cuotasCubiertas) {
      if (c.numeroCuota == 0) {
        partes.add('Mora${c.completada ? ' ✓' : ''}');
      } else {
        partes.add('Cuota #${c.numeroCuota}${c.completada ? ' ✓' : ' (parcial)'}');
      }
    }
    return partes.isEmpty ? 'Abono' : partes.join(' + ');
  }
}
