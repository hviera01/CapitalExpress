import 'package:cloud_firestore/cloud_firestore.dart';

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

  Map<String, dynamic> toMap() => {
        'numeroCuota': numeroCuota,
        'montoAplicado': montoAplicado,
        'totalCuota': totalCuota,
      };
}

/// Espejo del doc `pagos` en Firestore (ui/models/PagoItem.kt).
class PagoModel {
  final String docId;
  final String cliente;
  final String prestamoId;
  final String fecha;
  final double monto;
  final double mora;
  final double interesTotal;
  final String cobrador;
  final String cobradorId;
  final String lugar;
  final String firma;
  final String tipoPago;
  final String metodoPago;
  final double? saldoRestante;
  final String numeroPrestamo;
  final int? numeroCuota;
  final String cuota; // ej. "Cuota #16" (descripcionCuotas)
  final String? notas;
  final String? fechaPago;
  final Timestamp? timestamp;
  final int cuotasTotales;
  final List<CuotaCubierta> cuotasCubiertas;

  const PagoModel({
    required this.docId,
    this.cliente = '',
    this.prestamoId = '',
    this.fecha = '',
    this.monto = 0,
    this.mora = 0,
    this.interesTotal = 0,
    this.cobrador = '',
    this.cobradorId = '',
    this.lugar = '',
    this.firma = '',
    this.tipoPago = 'Efectivo',
    this.metodoPago = 'Efectivo',
    this.saldoRestante,
    this.numeroPrestamo = '',
    this.numeroCuota,
    this.cuota = '',
    this.notas,
    this.fechaPago,
    this.timestamp,
    this.cuotasTotales = 0,
    this.cuotasCubiertas = const [],
  });

  factory PagoModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    double dd(String k) => (d[k] as num?)?.toDouble() ?? 0.0;
    return PagoModel(
      docId: doc.id,
      cliente: (d['cliente'] ?? '') as String,
      prestamoId: (d['prestamoId'] ?? '') as String,
      fecha: (d['fecha'] ?? '') as String,
      monto: dd('monto'),
      mora: dd('mora'),
      interesTotal: dd('interesTotal'),
      cobrador: (d['cobrador'] ?? '') as String,
      cobradorId: (d['cobradorId'] ?? '') as String,
      lugar: (d['lugar'] ?? '') as String,
      firma: (d['firma'] ?? '') as String,
      tipoPago: (d['tipoPago'] ?? 'Efectivo') as String,
      metodoPago: (d['metodoPago'] ?? 'Efectivo') as String,
      saldoRestante: (d['saldoRestante'] as num?)?.toDouble(),
      numeroPrestamo: (d['numeroPrestamo'] ?? '') as String,
      numeroCuota: (d['numeroCuota'] as num?)?.toInt(),
      // `cuota` en Firestore realmente guarda la descripcion ("Cuota #16"),
      // ver descripcionCuotas en RegistrarPagoScreen.kt (bug de v14: leer
      // este campo, no numeroCuota, para el numero real de cuota).
      cuota: (d['descripcionCuotas'] ?? d['cuota'] ?? '') as String,
      notas: d['notas'] as String?,
      fechaPago: d['fechaPago'] as String?,
      timestamp: d['timestamp'] as Timestamp?,
      cuotasTotales: (d['cuotasTotales'] as num?)?.toInt() ?? 0,
      cuotasCubiertas: (d['cuotasCubiertas'] as List?)
              ?.map((m) => CuotaCubierta.fromMap(Map<String, dynamic>.from(m as Map)))
              .toList() ??
          const [],
    );
  }
}
