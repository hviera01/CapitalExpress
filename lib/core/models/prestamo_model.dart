import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/firestore_parse.dart';

/// Espejo del doc `prestamos` en Firestore (ui/models/Prestamo.kt +
/// campos extra escritos por otras pantallas que no estaban en el data
/// class original pero si en los mapas de escritura: clienteId, plazo,
/// morasAplicadas, morasIndividuales, eliminadoPor).
class MoraIndividual {
  final String id;
  final double monto;
  final Timestamp? fechaAplicada;
  final String aplicadaPor;
  final bool sintetica;

  const MoraIndividual({
    required this.id,
    required this.monto,
    this.fechaAplicada,
    this.aplicadaPor = '',
    this.sintetica = false,
  });

  factory MoraIndividual.fromMap(Map<String, dynamic> m) => MoraIndividual(
        id: (m['id'] ?? '') as String,
        monto: (m['monto'] as num?)?.toDouble() ?? 0.0,
        fechaAplicada: asTimestamp(m['fechaAplicada']),
        aplicadaPor: (m['aplicadaPor'] ?? '') as String,
        sintetica: (m['sintetica'] ?? false) as bool,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'monto': monto,
        if (fechaAplicada != null) 'fechaAplicada': fechaAplicada,
        'aplicadaPor': aplicadaPor,
        'sintetica': sintetica,
      };
}

class PrestamoModel {
  final String prestamoId;
  final String clienteId;
  final double monto;
  final double interes;
  final double saldo;
  final double saldoAnterior;
  final double totalPagar;
  final double montoPagado;
  final String estado;
  final double? interesMensual;
  final double? interesTotal;
  final double? cuota;
  final String lugar;
  final int? numeroPrestamo;
  final String garantia;
  final bool eliminado;
  final String? eliminadoPor;
  final String cobradorAsignado;
  final int cuotas;
  final String plazo;
  final double mora;
  final double? interesManual;
  final double? pagos;
  final String firma;
  final String observaciones;
  final Timestamp? fechaCreacion;
  final Timestamp? fechaUltimaActualizacion;
  final Timestamp? fechaCancelacion;
  final List<String> fotos;
  final dynamic proximoPago; // String "saldado" o fecha segun el flujo
  final List<String> morasAplicadas;
  final List<MoraIndividual> morasIndividuales;

  const PrestamoModel({
    required this.prestamoId,
    this.clienteId = '',
    this.monto = 0,
    this.interes = 0,
    this.saldo = 0,
    this.saldoAnterior = 0,
    this.totalPagar = 0,
    this.montoPagado = 0,
    this.estado = '',
    this.interesMensual,
    this.interesTotal,
    this.cuota,
    this.lugar = '',
    this.numeroPrestamo,
    this.garantia = '',
    this.eliminado = false,
    this.eliminadoPor,
    this.cobradorAsignado = '',
    this.cuotas = 0,
    this.plazo = '',
    this.mora = 0,
    this.interesManual,
    this.pagos,
    this.firma = '',
    this.observaciones = '',
    this.fechaCreacion,
    this.fechaUltimaActualizacion,
    this.fechaCancelacion,
    this.fotos = const [],
    this.proximoPago,
    this.morasAplicadas = const [],
    this.morasIndividuales = const [],
  });

  factory PrestamoModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    double? dOrNull(String k) => (d[k] as num?)?.toDouble();
    double dd(String k) => (d[k] as num?)?.toDouble() ?? 0.0;
    return PrestamoModel(
      prestamoId: doc.id,
      clienteId: (d['clienteId'] ?? '') as String,
      monto: dd('monto'),
      interes: dd('interes'),
      saldo: dd('saldo'),
      saldoAnterior: dd('saldoAnterior'),
      totalPagar: dd('totalPagar'),
      montoPagado: dd('montoPagado'),
      estado: (d['estado'] ?? '') as String,
      interesMensual: dOrNull('interesMensual'),
      interesTotal: dOrNull('interesTotal'),
      cuota: dOrNull('cuota'),
      lugar: (d['lugar'] ?? '') as String,
      numeroPrestamo: (d['numeroPrestamo'] as num?)?.toInt(),
      garantia: (d['garantia'] ?? '') as String,
      eliminado: (d['eliminado'] ?? false) as bool,
      eliminadoPor: d['eliminadoPor'] as String?,
      cobradorAsignado: (d['cobradorAsignado'] ?? '') as String,
      cuotas: (d['cuotas'] as num?)?.toInt() ?? 0,
      plazo: (d['plazo'] ?? '') as String,
      mora: dd('mora'),
      interesManual: dOrNull('interesManual'),
      pagos: dOrNull('pagos'),
      firma: (d['firma'] ?? '') as String,
      observaciones: (d['observaciones'] ?? '') as String,
      fechaCreacion: asTimestamp(d['fechaCreacion']),
      fechaUltimaActualizacion: asTimestamp(d['fechaUltimaActualizacion']),
      fechaCancelacion: asTimestamp(d['fechaCancelacion']),
      fotos: (d['fotos'] as List?)?.cast<String>() ?? const [],
      proximoPago: d['proximoPago'],
      morasAplicadas: (d['morasAplicadas'] as List?)?.cast<String>() ?? const [],
      morasIndividuales: (d['morasIndividuales'] as List?)
              ?.map((m) => MoraIndividual.fromMap(Map<String, dynamic>.from(m as Map)))
              .toList() ??
          const [],
    );
  }
}
