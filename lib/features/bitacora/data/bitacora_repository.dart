import 'package:cloud_firestore/cloud_firestore.dart';

import 'bitacora_model.dart';

/// Bitacora de Seguridad: registra QUIEN elimino QUE y CUANDO. Se
/// llama desde los repositorios reales (cliente/prestamo/pago) justo
/// despues de borrar -- ver ClienteRepository.eliminar,
/// PrestamoRepository.marcarEliminado/eliminarPermanente,
/// PagoRepository.eliminarConReversion.
///
/// `registrar` es "fire and forget" a proposito (mismo criterio que
/// DispositivoRepository.reportar): un fallo aca (sin internet, regla
/// de Firestore, lo que sea) NUNCA debe hacer fallar ni demorar la
/// eliminacion real que ya se aplico -- por eso no se hace `await` en
/// los call sites y el error se traga en silencio.
class BitacoraRepository {
  final _col = FirebaseFirestore.instance.collection('bitacora');

  void registrar({
    required String accion,
    required String entidadTipo,
    required String descripcion,
    required String usuarioUid,
    required String usuarioNombre,
  }) {
    _registrar(
      accion: accion,
      entidadTipo: entidadTipo,
      descripcion: descripcion,
      usuarioUid: usuarioUid,
      usuarioNombre: usuarioNombre,
    );
  }

  Future<void> _registrar({
    required String accion,
    required String entidadTipo,
    required String descripcion,
    required String usuarioUid,
    required String usuarioNombre,
  }) async {
    try {
      await _col.add({
        'accion': accion,
        'entidadTipo': entidadTipo,
        'descripcion': descripcion,
        'usuarioUid': usuarioUid,
        'usuarioNombre': usuarioNombre,
        'fecha': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Silencioso a proposito: ver comentario de la clase.
    }
  }

  /// Ultimas `limite` entradas -- acotado a proposito (ver
  /// BitacoraScreen) para que la pantalla sea liviana incluso con
  /// meses de historial: no hace falta bajar TODO el historial para
  /// mostrar "lo reciente" agrupado por fecha.
  Stream<List<BitacoraModel>> streamRecientes({int limite = 300}) {
    return _col
        .orderBy('fecha', descending: true)
        .limit(limite)
        .snapshots()
        .map((snap) => snap.docs.map((d) => BitacoraModel.fromMap(d.id, d.data())).toList());
  }
}
