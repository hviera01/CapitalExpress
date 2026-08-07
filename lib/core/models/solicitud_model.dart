import 'package:cloud_firestore/cloud_firestore.dart';

/// Espejo del doc `solicitudes_prestamo` en Firestore (ui/models/SolicitudModel.kt).
/// Un cobrador la crea pidiendo un prestamo nuevo; el admin la aprueba/rechaza
/// y, al aprobar, se crea el doc real en `prestamos`.
class SolicitudModel {
  final String id;
  final String cliente;
  final String clienteId;
  final double monto;
  final double interesManual;
  final double interesMensual;
  final double interesTotal;
  final double totalPagar;
  final double cuota;
  final int cuotas;
  final String plazo;
  final String fecha;
  final String lugar;
  final String? firma;
  final String estado; // "pendiente" | "aprobada" | "rechazada"
  final String observaciones;
  final List<String> fotos;
  final double mora;
  final String garantia;
  final String cobrador;
  final String? cobradorUid;
  final String cobradorSolicitante;
  final int diasEfectivos;
  final Timestamp? fechaCreacion;

  const SolicitudModel({
    required this.id,
    this.cliente = '',
    this.clienteId = '',
    this.monto = 0,
    this.interesManual = 0,
    this.interesMensual = 0,
    this.interesTotal = 0,
    this.totalPagar = 0,
    this.cuota = 0,
    this.cuotas = 0,
    this.plazo = '',
    this.fecha = '',
    this.lugar = '',
    this.firma,
    this.estado = 'pendiente',
    this.observaciones = '',
    this.fotos = const [],
    this.mora = 0,
    this.garantia = '',
    this.cobrador = '',
    this.cobradorUid,
    this.cobradorSolicitante = '',
    this.diasEfectivos = 0,
    this.fechaCreacion,
  });

  factory SolicitudModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    double dd(String k) => (d[k] as num?)?.toDouble() ?? 0.0;
    return SolicitudModel(
      id: doc.id,
      cliente: (d['cliente'] ?? '') as String,
      clienteId: (d['clienteId'] ?? '') as String,
      monto: dd('monto'),
      interesManual: dd('interesManual'),
      interesMensual: dd('interesMensual'),
      interesTotal: dd('interesTotal'),
      totalPagar: dd('totalPagar'),
      cuota: dd('cuota'),
      cuotas: (d['cuotas'] as num?)?.toInt() ?? 0,
      plazo: (d['plazo'] ?? '') as String,
      fecha: (d['fecha'] ?? '') as String,
      lugar: (d['lugar'] ?? '') as String,
      firma: d['firma'] as String?,
      estado: (d['estado'] ?? 'pendiente') as String,
      observaciones: (d['observaciones'] ?? '') as String,
      fotos: (d['fotos'] as List?)?.cast<String>() ?? const [],
      mora: dd('mora'),
      garantia: (d['garantia'] ?? '') as String,
      cobrador: (d['cobrador'] ?? '') as String,
      cobradorUid: d['cobradorUid'] as String?,
      cobradorSolicitante: (d['cobradorSolicitante'] ?? '') as String,
      diasEfectivos: (d['diasEfectivos'] as num?)?.toInt() ?? 0,
      fechaCreacion: d['fechaCreacion'] as Timestamp?,
    );
  }
}
