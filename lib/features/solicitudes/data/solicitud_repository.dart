import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/solicitud_model.dart';
import '../../../core/utils/prestamo_calculos.dart';
import '../../bitacora/data/bitacora_repository.dart';

class SolicitudRepository {
  final _col = FirebaseFirestore.instance.collection('solicitudes_prestamo');

  /// En vivo: la pantalla de Solicitudes siempre tiene que estar
  /// actualizada apenas un cobrador manda una nueva.
  Stream<List<SolicitudModel>> streamPendientes({String? cobradorUid}) {
    Query<Map<String, dynamic>> query = _col.where('estado', isEqualTo: 'pendiente');
    if (cobradorUid != null) {
      query = query.where('cobradorUid', isEqualTo: cobradorUid);
    }
    return query.snapshots().map((snap) {
      final solicitudes = <SolicitudModel>[];
      for (final doc in snap.docs) {
        try {
          solicitudes.add(SolicitudModel.fromDoc(doc));
        } catch (_) {
          // documento con formato inesperado: se omite.
        }
      }
      solicitudes.sort((a, b) =>
          (b.fechaCreacion?.compareTo(a.fechaCreacion ?? b.fechaCreacion!) ?? 0));
      return solicitudes;
    });
  }

  Stream<SolicitudModel?> streamPorId(String id) {
    return _col.doc(id).snapshots().map((doc) => doc.exists ? SolicitudModel.fromDoc(doc) : null);
  }

  /// Mismos campos que escribe SolicitudPrestamoScreen.kt (ver
  /// investigacion): a diferencia de Crear Prestamo, `mora` aca es la
  /// tarifa diaria que propone el cobrador (no mora ya adeudada), y NO
  /// se genera numeroPrestamo todavia -- eso pasa recien si se aprueba.
  Future<void> crear({
    required String clienteId,
    required String clienteNombre,
    required double monto,
    required bool usarInteresMensual,
    required double interesMensual,
    required double interesTotalFijo,
    required double interesCalculado,
    required double moraDiaria,
    required double totalAPagar,
    required double cuotaEstimada,
    required int cuotas,
    required String plazo,
    required DateTime fechaInicio,
    required String lugar,
    required String firma,
    required String garantia,
    required String observaciones,
    required List<String> fotos,
    required int diasEfectivos,
    required String cobradorNombre,
    required String cobradorUid,
    required String numeroCobrador,
  }) async {
    final f = fechaInicio;
    final fechaStr =
        '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
    final proximaFecha = calcularProximaFecha(fechaInicio, plazo);
    final docRef = _col.doc();

    await docRef.set({
      'id': docRef.id,
      'solicitudId': docRef.id,
      'cliente': clienteNombre,
      'clienteId': clienteId,
      'monto': monto,
      'interes': interesCalculado,
      'interesMensual': usarInteresMensual ? interesMensual : 0.0,
      'interesTotal': !usarInteresMensual ? interesTotalFijo : interesCalculado,
      'usarInteresMensual': usarInteresMensual,
      'interesTotalFijo': !usarInteresMensual ? interesTotalFijo : 0.0,
      'interesManual': !usarInteresMensual ? interesTotalFijo : 0.0,
      'mora': moraDiaria,
      'totalPagar': totalAPagar,
      'cuota': cuotaEstimada,
      'cuotas': cuotas,
      'plazo': plazo,
      'fecha': fechaStr,
      'fechaTimestamp': Timestamp.fromDate(fechaInicio),
      'fechaCreacion': FieldValue.serverTimestamp(),
      'lugar': lugar,
      'firma': firma,
      'garantia': garantia,
      'cobrador': cobradorNombre,
      'cobradorSolicitante': cobradorNombre,
      'numeroCobrador': numeroCobrador,
      'cobradorUid': cobradorUid,
      'proximoPago': Timestamp.fromDate(proximaFecha),
      'montoPagado': 0.0,
      'saldoAnterior': monto,
      'estado': 'pendiente',
      'observaciones': observaciones,
      'fotos': fotos,
      'diasEfectivos': diasEfectivos.toDouble(),
      'saldo': totalAPagar,
      'tipoDocumento': 'solicitud',
      'requiereAprobacion': true,
    });
  }

  /// Aprobar: crea el prestamo real (mismo numero/forma que Crear
  /// Prestamo) y borra la solicitud -- igual que
  /// SolicitudesAdminScreen.kt (no se guarda un historial de aprobadas,
  /// se elimina el doc al aprobar).
  Future<void> aprobar(
    String solicitudId, {
    required String usuarioUid,
    required String usuarioNombre,
    String descripcionSolicitud = '',
  }) async {
    await _col.doc(solicitudId).delete();
    BitacoraRepository().registrar(
      accion: 'aprobar_solicitud',
      entidadTipo: 'solicitud',
      descripcion: descripcionSolicitud.isNotEmpty
          ? descripcionSolicitud
          : 'Solicitud (ID: $solicitudId)',
      usuarioUid: usuarioUid,
      usuarioNombre: usuarioNombre,
    );
  }

  /// Rechazar: borrado directo, sin dejar rastro -- igual que el
  /// original (no existe un estado "rechazada" persistido).
  Future<void> rechazar(
    String solicitudId, {
    required String usuarioUid,
    required String usuarioNombre,
    String descripcionSolicitud = '',
  }) async {
    await _col.doc(solicitudId).delete();
    BitacoraRepository().registrar(
      accion: 'rechazar_solicitud',
      entidadTipo: 'solicitud',
      descripcion: descripcionSolicitud.isNotEmpty
          ? descripcionSolicitud
          : 'Solicitud (ID: $solicitudId)',
      usuarioUid: usuarioUid,
      usuarioNombre: usuarioNombre,
    );
  }

  Future<int> contarPendientes({String? cobradorUid}) async {
    Query<Map<String, dynamic>> query = _col.where('estado', isEqualTo: 'pendiente');
    if (cobradorUid != null) {
      query = query.where('cobradorUid', isEqualTo: cobradorUid);
    }
    final agg = await query.count().get();
    return agg.count ?? 0;
  }
}
