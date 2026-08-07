import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/firestore_parse.dart';

/// Una cuota cubierta por un pago (parte del resultado de la cascada
/// de distribucion, persistida junto al pago para poder reconstruir
/// la cobertura de cuotas despues). Cuota 0 = abono aplicado a mora.
class CuotaCubierta {
  final int numeroCuota;
  final double montoAplicado;
  final double totalCuota;

  const CuotaCubierta({
    required this.numeroCuota,
    required this.montoAplicado,
    required this.totalCuota,
  });

  factory CuotaCubierta.fromMap(Map<String, dynamic> m) => CuotaCubierta(
        numeroCuota: (m['numeroCuota'] as num?)?.toInt() ?? 0,
        montoAplicado: (m['montoAplicado'] as num?)?.toDouble() ?? 0.0,
        totalCuota: (m['totalCuota'] as num?)?.toDouble() ?? 0.0,
      );
}

/// Espejo del doc `pagos` en Firestore -- nombres de campo verificados
/// contra el sitio real de escritura (RegistrarPagoScreen.kt, funcion
/// que arma el mapa que se guarda), no contra el data class PagoItem.kt
/// que resulto desactualizado igual que paso con ClienteModel.
class PagoModel {
  final String docId;
  final String clienteId;
  final String clienteNombre;
  final String prestamoId;
  final String numeroPrestamo;
  final double monto;
  final double mora;
  final Timestamp? fechaPago;
  final String registradoPor; // uid del cobrador
  final String nombreCobrador;
  final double? saldoRestante;
  final String lugar;
  final String firma;
  final String metodoPago;
  final String plazo;
  final Timestamp? proximaFechaProgramada;
  final int totalCuotasCompletas;
  final String descripcionCuotas; // ej. "Cuota #16"
  final bool sistemaPagoEnCascada;
  final List<CuotaCubierta> cuotasCubiertas;

  const PagoModel({
    required this.docId,
    this.clienteId = '',
    this.clienteNombre = '',
    this.prestamoId = '',
    this.numeroPrestamo = '',
    this.monto = 0,
    this.mora = 0,
    this.fechaPago,
    this.registradoPor = '',
    this.nombreCobrador = '',
    this.saldoRestante,
    this.lugar = '',
    this.firma = '',
    this.metodoPago = 'Efectivo',
    this.plazo = '',
    this.proximaFechaProgramada,
    this.totalCuotasCompletas = 0,
    this.descripcionCuotas = '',
    this.sistemaPagoEnCascada = false,
    this.cuotasCubiertas = const [],
  });

  double get total => monto + mora;

  factory PagoModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    double dd(String k) => (d[k] as num?)?.toDouble() ?? 0.0;
    return PagoModel(
      docId: doc.id,
      clienteId: (d['clienteId'] ?? '') as String,
      clienteNombre: (d['clienteNombre'] ?? '') as String,
      prestamoId: (d['prestamoId'] ?? '') as String,
      numeroPrestamo: (d['numeroPrestamo'] ?? '').toString(),
      monto: dd('monto'),
      mora: dd('mora'),
      fechaPago: asTimestamp(d['fechaPago']),
      registradoPor: (d['registradoPor'] ?? '') as String,
      nombreCobrador: (d['nombreCobrador'] ?? '') as String,
      saldoRestante: (d['saldoRestante'] as num?)?.toDouble(),
      lugar: (d['lugar'] ?? '') as String,
      firma: (d['firma'] ?? '') as String,
      metodoPago: (d['metodoPago'] ?? 'Efectivo') as String,
      plazo: (d['plazo'] ?? '') as String,
      proximaFechaProgramada: asTimestamp(d['proximaFechaProgramada']),
      totalCuotasCompletas: (d['totalCuotasCompletas'] as num?)?.toInt() ?? 0,
      descripcionCuotas: (d['descripcionCuotas'] ?? '') as String,
      sistemaPagoEnCascada: (d['sistemaPagoEnCascada'] ?? false) as bool,
      cuotasCubiertas: (d['cuotasCubiertas'] as List?)
              ?.map((m) => CuotaCubierta.fromMap(Map<String, dynamic>.from(m as Map)))
              .toList() ??
          const [],
    );
  }
}
