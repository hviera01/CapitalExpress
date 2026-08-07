import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/firestore_parse.dart';

/// Espejo del doc `prestamos` en Firestore, tal como lo escribe
/// CrearPrestamoScreen.kt (fuente de verdad real, no el data class
/// ui/models/Prestamo.kt que estaba desactualizado en algunos campos).
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
  final String cliente; // nombre del cliente, denormalizado
  final double monto;
  final double interes; // = interesTotal calculado (monto en L, no %)
  final double saldo;
  final double saldoAnterior;
  final double totalPagar;
  final double montoPagado;
  final String estado; // "activo" | "mora" | "saldado" | ...
  final double interesMensual; // % mensual (0 si se uso interes total fijo)
  final bool usarInteresMensual;
  final double interesTotalFijo;
  final double cuota; // cuota estimada por periodo
  final String lugar;
  final String numeroPrestamo; // ej. "SDG-00001"
  final String garantia;
  final bool eliminado;
  final String? eliminadoPor;
  final String cobrador; // nombre, denormalizado
  final String numeroCobrador;
  final String cobradorUid;
  final String cobradorAsignado;
  final int cuotas;
  final String plazo; // "Diario" | "Lunes a Sábado" | "Semanal" | "Quincenal" | "Mensual" | "Bimestral"
  final double mora; // mora ADEUDADA acumulada (no la tarifa diaria)
  final String firma;
  final String observaciones;
  final Timestamp? fecha; // fecha de inicio del prestamo
  final Timestamp? fechaCreacion;
  final Timestamp? fechaUltimaActualizacion;
  final Timestamp? fechaCancelacion;
  final List<String> fotos;
  final dynamic proximoPago; // Timestamp o "saldado"
  final int diasEfectivos;
  final List<String> morasAplicadas;
  final List<MoraIndividual> morasIndividuales;

  const PrestamoModel({
    required this.prestamoId,
    this.clienteId = '',
    this.cliente = '',
    this.monto = 0,
    this.interes = 0,
    this.saldo = 0,
    this.saldoAnterior = 0,
    this.totalPagar = 0,
    this.montoPagado = 0,
    this.estado = '',
    this.interesMensual = 0,
    this.usarInteresMensual = true,
    this.interesTotalFijo = 0,
    this.cuota = 0,
    this.lugar = '',
    this.numeroPrestamo = '',
    this.garantia = '',
    this.eliminado = false,
    this.eliminadoPor,
    this.cobrador = '',
    this.numeroCobrador = '',
    this.cobradorUid = '',
    this.cobradorAsignado = '',
    this.cuotas = 0,
    this.plazo = '',
    this.mora = 0,
    this.firma = '',
    this.observaciones = '',
    this.fecha,
    this.fechaCreacion,
    this.fechaUltimaActualizacion,
    this.fechaCancelacion,
    this.fotos = const [],
    this.proximoPago,
    this.diasEfectivos = 0,
    this.morasAplicadas = const [],
    this.morasIndividuales = const [],
  });

  /// `numeroPrestamo` deberia ser siempre String ("SDG-00001") pero por
  /// las dudas se tolera si algun doc viejo lo guardo como numero.
  static String _numeroPrestamo(dynamic v) {
    if (v == null) return '';
    return v.toString();
  }

  factory PrestamoModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    double dd(String k) => (d[k] as num?)?.toDouble() ?? 0.0;
    return PrestamoModel(
      prestamoId: doc.id,
      clienteId: (d['clienteId'] ?? '') as String,
      cliente: (d['cliente'] ?? '') as String,
      monto: dd('monto'),
      interes: dd('interes'),
      saldo: dd('saldo'),
      saldoAnterior: dd('saldoAnterior'),
      totalPagar: dd('totalPagar'),
      montoPagado: dd('montoPagado'),
      estado: (d['estado'] ?? '') as String,
      interesMensual: dd('interesMensual'),
      usarInteresMensual: (d['usarInteresMensual'] ?? true) as bool,
      interesTotalFijo: dd('interesTotalFijo'),
      cuota: dd('cuota'),
      lugar: (d['lugar'] ?? '') as String,
      numeroPrestamo: _numeroPrestamo(d['numeroPrestamo']),
      garantia: (d['garantia'] ?? '') as String,
      eliminado: (d['eliminado'] ?? false) as bool,
      eliminadoPor: d['eliminadoPor'] as String?,
      cobrador: (d['cobrador'] ?? '') as String,
      numeroCobrador: (d['numeroCobrador'] ?? '') as String,
      cobradorUid: (d['cobradorUid'] ?? '') as String,
      cobradorAsignado: (d['cobradorAsignado'] ?? '') as String,
      cuotas: (d['cuotas'] as num?)?.toInt() ?? 0,
      plazo: (d['plazo'] ?? '') as String,
      mora: dd('mora'),
      firma: (d['firma'] ?? '') as String,
      observaciones: (d['observaciones'] ?? '') as String,
      fecha: asTimestamp(d['fecha']),
      fechaCreacion: asTimestamp(d['fechaCreacion']),
      fechaUltimaActualizacion: asTimestamp(d['fechaUltimaActualizacion']),
      fechaCancelacion: asTimestamp(d['fechaCancelacion']),
      fotos: (d['fotos'] as List?)?.cast<String>() ?? const [],
      proximoPago: d['proximoPago'],
      diasEfectivos: (d['diasEfectivos'] as num?)?.toInt() ?? 0,
      morasAplicadas: (d['morasAplicadas'] as List?)?.cast<String>() ?? const [],
      morasIndividuales: (d['morasIndividuales'] as List?)
              ?.map((m) => MoraIndividual.fromMap(Map<String, dynamic>.from(m as Map)))
              .toList() ??
          const [],
    );
  }
}
