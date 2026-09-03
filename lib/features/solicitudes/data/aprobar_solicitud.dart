import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/solicitud_model.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/prestamo_calculos.dart';
import '../../prestamos/data/prestamo_repository.dart';
import 'solicitud_repository.dart';

class SolicitudAprobada {
  final String prestamoId;
  final String numeroPrestamo;

  const SolicitudAprobada({required this.prestamoId, required this.numeroPrestamo});
}

/// Aprobar una solicitud: genera el numeroPrestamo real (mismo
/// contador que Crear Préstamo), crea el doc en `prestamos` con la
/// misma forma que una creacion directa, actualiza el cliente, y borra
/// la solicitud -- igual que aceptarSolicitudYGenerarRecibo en
/// SolicitudesAdminScreen.kt. `mora` siempre arranca en 0.0 (la tarifa
/// diaria que puso el cobrador en la solicitud no es mora adeudada).
///
/// Diferencia a proposito vs el original: alli las fotos de la
/// solicitud eran URIs locales del telefono y se descartaban al
/// aprobar; aca ya son URLs reales de Firebase Storage (se subieron al
/// crear la solicitud), asi que SI se copian al prestamo creado.
Future<SolicitudAprobada> aprobarSolicitud({
  required PrestamoRepository prestamoRepo,
  required SolicitudRepository solicitudRepo,
  required SolicitudModel s,
  required String usuarioUid,
  required String usuarioNombre,
}) async {
  final numeroPrestamo = await prestamoRepo.generarNumeroPrestamo(s.cliente);

  final fechaInicio = DateTime.now();
  final proximaFecha = calcularProximaFecha(fechaInicio, s.plazo);

  final prestamoId = await prestamoRepo.crear({
    'numeroPrestamo': numeroPrestamo,
    'cliente': s.cliente,
    'clienteId': s.clienteId,
    'monto': s.monto,
    'interes': s.interesTotal,
    'interesMensual': s.interesMensual,
    'interesTotal': s.interesTotal,
    'usarInteresMensual': s.interesMensual > 0,
    'interesTotalFijo': s.interesManual,
    'mora': 0.0,
    'totalPagar': s.totalPagar,
    'cuota': s.cuota,
    'cuotas': s.cuotas,
    'plazo': s.plazo,
    'fecha': Timestamp.fromDate(fechaInicio),
    'lugar': s.lugar,
    'firma': s.firma ?? '',
    'garantia': s.garantia,
    'observaciones': s.observaciones,
    'cobrador': s.cobrador,
    'numeroCobrador': '',
    'cobradorUid': s.cobradorUid ?? '',
    'cobradorAsignado': s.cobradorUid ?? '',
    // El campo real que usan las consultas por cobrador es el array.
    'cobradoresAsignados': (s.cobradorUid ?? '').isNotEmpty ? [s.cobradorUid] : [],
    'proximoPago': Timestamp.fromDate(proximaFecha),
    'montoPagado': 0.0,
    'saldoAnterior': s.monto,
    'estado': 'activo',
    'fotos': s.fotos,
    'diasEfectivos': s.diasEfectivos,
    'saldo': s.totalPagar,
    'eliminado': false,
    'origenSolicitud': true,
    'solicitudId': s.id,
  });

  try {
    final clienteRef = FirebaseFirestore.instance.collection('clientes').doc(s.clienteId);
    final clienteDoc = await clienteRef.get();
    final data = <String, dynamic>{'tienePrestamo': true};
    final cobradorActual = (clienteDoc.data()?['cobradorAsignado'] ?? '') as String;
    if (cobradorActual.isEmpty && (s.cobradorUid ?? '').isNotEmpty) {
      data['cobradorAsignado'] = s.cobradorUid;
      data['cobradoresAsignados'] = [s.cobradorUid];
    }
    await clienteRef.update(data);
  } catch (_) {
    // best-effort, no debe tumbar la aprobacion si esto falla.
  }

  await solicitudRepo.aprobar(
    s.id,
    usuarioUid: usuarioUid,
    usuarioNombre: usuarioNombre,
    descripcionSolicitud: '${s.cliente} - ${formatearLempiras(s.monto)}',
  );

  return SolicitudAprobada(prestamoId: prestamoId, numeroPrestamo: numeroPrestamo);
}
