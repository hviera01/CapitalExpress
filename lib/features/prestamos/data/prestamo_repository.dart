import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/prestamo_model.dart';
import '../../../core/utils/normalizar_texto.dart';
import '../../bitacora/data/bitacora_repository.dart';

class PrestamoRepository {
  final _db = FirebaseFirestore.instance;
  final _col = FirebaseFirestore.instance.collection('prestamos');
  final _contadorRef =
      FirebaseFirestore.instance.collection('configuracion').doc('contadorPrestamos');

  /// Mismo formato que PrestamoNumberHelper.kt: [Iniciales]-[00001].
  String _inicialesCliente(String nombreCompleto) {
    final palabras = nombreCompleto.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (palabras.isEmpty) return 'CLI';
    if (palabras.length == 1) {
      return palabras[0].substring(0, palabras[0].length.clamp(0, 3)).toUpperCase();
    }
    if (palabras.length == 2) {
      return (palabras[0][0] + palabras[1].substring(0, palabras[1].length.clamp(0, 2)))
          .toUpperCase();
    }
    return (palabras[0][0] + palabras[1][0] + palabras[2][0]).toUpperCase();
  }

  Future<String> generarNumeroPrestamo(String clienteNombre) async {
    final iniciales = _inicialesCliente(clienteNombre);

    final siguiente = await _db.runTransaction<int>((tx) async {
      final snap = await tx.get(_contadorRef);
      final actual = snap.exists ? ((snap.data()?['ultimoNumero'] as num?)?.toInt() ?? 0) : 0;
      final nuevo = actual + 1;
      tx.set(_contadorRef, {'ultimoNumero': nuevo});
      return nuevo;
    });

    final numeroFormateado = siguiente.toString().padLeft(5, '0');
    return '$iniciales-$numeroFormateado';
  }

  /// Admin ve todos; cobrador solo los suyos (`cobradorAsignado == uid`).
  /// `incluirEliminados` replica el toggle "Ver eliminados" de PrestamosAdmin.kt.
  Stream<List<PrestamoModel>> streamPrestamos({
    String? cobradorUid,
    bool incluirEliminados = false,
  }) {
    Query<Map<String, dynamic>> query = _col;
    if (cobradorUid != null) {
      query = query.where('cobradoresAsignados', arrayContains: cobradorUid);
    }
    return query.snapshots().map((snap) {
      final prestamos = <PrestamoModel>[];
      for (final doc in snap.docs) {
        try {
          final p = PrestamoModel.fromDoc(doc);
          if (p.eliminado && !incluirEliminados) continue;
          prestamos.add(p);
        } catch (_) {
          // documento con un campo en formato inesperado: se omite, no
          // debe tumbar el resto de la lista (mismo criterio que clientes).
        }
      }
      prestamos.sort((a, b) => (b.fechaCreacion?.compareTo(a.fechaCreacion ?? b.fechaCreacion!) ?? 0));
      return prestamos;
    });
  }

  /// Trae TODOS los prestamos no eliminados del alcance (para el Reporte
  /// de Clientes, que necesita el universo completo -- no es para
  /// pantallas de navegacion cotidiana, ahi se usa `buscar`).
  Future<List<PrestamoModel>> obtenerTodos({String? cobradorUid}) async {
    Query<Map<String, dynamic>> query = _col.where('eliminado', isEqualTo: false);
    if (cobradorUid != null) {
      query = query.where('cobradoresAsignados', arrayContains: cobradorUid);
    }
    final snap = await query.get();
    final prestamos = <PrestamoModel>[];
    for (final doc in snap.docs) {
      try {
        prestamos.add(PrestamoModel.fromDoc(doc));
      } catch (_) {
        // documento con formato inesperado: se omite.
      }
    }
    return prestamos;
  }

  /// Para Cobros/Notificaciones: igual que [obtenerTodos] pero ADEMAS
  /// incluye los prestamos de clientes asignados a este cobrador aunque
  /// el prestamo en si no tenga a este cobrador en su propio
  /// `cobradoresAsignados`. Esto replica una inconsistencia real de los
  /// datos (confirmada contra Firestore): un cliente puede estar
  /// asignado a un cobrador mientras que uno de sus prestamos quedo
  /// asignado a otro (por reasignaciones parciales o datos viejos), y
  /// NotificacionesScreen.kt en el sistema original SI encuentra esos
  /// casos combinando varias fuentes (clientes.cobradoresAsignados +
  /// prestamos.cobradoresAsignados). Sin esto, Cobros mostraba muchos
  /// menos prestamos que el sistema viejo para el mismo cobrador.
  Future<List<PrestamoModel>> obtenerParaNotificaciones({String? cobradorUid}) async {
    if (cobradorUid == null) return obtenerTodos();

    final porPrestamo = await obtenerTodos(cobradorUid: cobradorUid);
    final porCliente = <PrestamoModel>[];

    final clientesSnap = await _db
        .collection('clientes')
        .where('cobradoresAsignados', arrayContains: cobradorUid)
        .get();
    final clienteIds = clientesSnap.docs.map((d) => d.id).toList();

    for (var i = 0; i < clienteIds.length; i += 10) {
      final lote = clienteIds.sublist(i, (i + 10).clamp(0, clienteIds.length));
      final snap = await _col
          .where('clienteId', whereIn: lote)
          .where('eliminado', isEqualTo: false)
          .get();
      for (final doc in snap.docs) {
        try {
          porCliente.add(PrestamoModel.fromDoc(doc));
        } catch (_) {
          // documento con formato inesperado: se omite.
        }
      }
    }

    final combinados = <String, PrestamoModel>{};
    for (final p in porPrestamo) {
      combinados[p.prestamoId] = p;
    }
    for (final p in porCliente) {
      combinados[p.prestamoId] = p;
    }
    return combinados.values.toList();
  }

  /// Cantidad total de prestamos del alcance dado (para el stat "Total"
  /// sin tener que bajar todos los documentos).
  Future<int> contar({String? cobradorUid, bool soloEliminados = false}) async {
    Query<Map<String, dynamic>> query = _col.where('eliminado', isEqualTo: soloEliminados);
    if (cobradorUid != null) {
      query = query.where('cobradoresAsignados', arrayContains: cobradorUid);
    }
    final agg = await query.count().get();
    return agg.count ?? 0;
  }

  Future<int> contarPorEstado(String estado, {String? cobradorUid}) async {
    Query<Map<String, dynamic>> query =
        _col.where('estado', isEqualTo: estado).where('eliminado', isEqualTo: false);
    if (cobradorUid != null) {
      query = query.where('cobradoresAsignados', arrayContains: cobradorUid);
    }
    final agg = await query.count().get();
    return agg.count ?? 0;
  }

  /// Busqueda puntual (no streaming), igual criterio que
  /// ClienteRepository.buscar: filtra por cobrador/estado/eliminado en
  /// el servidor y el texto libre en memoria sobre ese subconjunto --
  /// por eso no puede llevar `limit`, tiene que traer TODO el alcance
  /// ya acotado (un limit aca, como habia antes, dejaba prestamos
  /// invisibles en la busqueda apenas hubiera mas de 100 en el
  /// alcance, sin importar que se buscara).
  Future<List<PrestamoModel>> buscar({
    String? cobradorUid,
    String? estado,
    bool incluirEliminados = false,
    String texto = '',
  }) async {
    Query<Map<String, dynamic>> query = _col.where('eliminado', isEqualTo: incluirEliminados);
    if (cobradorUid != null) {
      query = query.where('cobradoresAsignados', arrayContains: cobradorUid);
    }
    if (estado != null) {
      query = query.where('estado', isEqualTo: estado);
    }

    final snap = await query.get();
    final prestamos = <PrestamoModel>[];
    for (final doc in snap.docs) {
      try {
        prestamos.add(PrestamoModel.fromDoc(doc));
      } catch (_) {
        // documento con formato inesperado: se omite.
      }
    }
    prestamos.sort((a, b) => (b.fechaCreacion?.compareTo(a.fechaCreacion ?? b.fechaCreacion!) ?? 0));

    if (texto.trim().isEmpty) return prestamos;
    return prestamos
        .where((p) => coincideBusqueda(p.cliente, texto) || coincideBusqueda(p.numeroPrestamo, texto))
        .toList();
  }

  Future<PrestamoModel?> obtenerPorId(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists) return null;
    return PrestamoModel.fromDoc(doc);
  }

  /// Igual que [obtenerPorId] pero en vivo -- para Detalle del Prestamo,
  /// asi si se aplica una mora o se registra/borra un pago desde otro
  /// lado la pantalla se actualiza sola, sin tener que salir y volver a
  /// entrar. Es un solo documento, no una lista grande, asi que mantener
  /// el stream abierto no pesa nada.
  Stream<PrestamoModel?> streamPorId(String id) {
    return _col.doc(id).snapshots().map((doc) => doc.exists ? PrestamoModel.fromDoc(doc) : null);
  }

  /// Prestamos de un cliente puntual (para el resumen del cliente).
  Future<List<PrestamoModel>> obtenerPorCliente(String clienteId) async {
    final snap = await _col.where('clienteId', isEqualTo: clienteId).get();
    return _prestamosValidos(snap.docs);
  }

  /// Igual que [obtenerPorCliente] pero en vivo (Resumen del Cliente).
  Stream<List<PrestamoModel>> streamPorCliente(String clienteId) {
    return _col
        .where('clienteId', isEqualTo: clienteId)
        .snapshots()
        .map((snap) => _prestamosValidos(snap.docs));
  }

  List<PrestamoModel> _prestamosValidos(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final prestamos = <PrestamoModel>[];
    for (final doc in docs) {
      try {
        final p = PrestamoModel.fromDoc(doc);
        if (!p.eliminado) prestamos.add(p);
      } catch (_) {
        // documento con formato inesperado: se omite.
      }
    }
    return prestamos;
  }

  /// El campo `tienePrestamo` guardado en el doc del cliente puede quedar
  /// obsoleto (se prende al crear el prestamo pero nunca se apaga cuando
  /// se salda) -- esto verifica el estado real contra `prestamos` en vez
  /// de confiar en esa bandera, para no mostrar "Con préstamo" en un
  /// cliente que ya no debe nada.
  Future<bool> tienePrestamoActivo(String clienteId) async {
    final prestamos = await obtenerPorCliente(clienteId);
    return prestamos.any((p) => p.saldo > 0.01);
  }

  /// Reasigna el cobrador del prestamo (usado al "Asignar Cobrador" a un
  /// cliente, que cascadea a todos sus prestamos activos). Un prestamo
  /// real puede tener VARIOS cobradores en `cobradoresAsignados` (el
  /// campo real de acceso, confirmado contra datos reales -- por eso
  /// las consultas por cobrador filtran por ese array, no por
  /// `cobradorAsignado`); reasignar desde esta pantalla reemplaza esa
  /// lista por el unico cobrador elegido, a proposito (la UI es un
  /// selector de uno solo). `cobradorAsignado` se mantiene en paralelo
  /// solo para mostrar el nombre en pantalla.
  Future<void> reasignarCobrador(String id, String cobradorUid, {String cobradorNombre = ''}) async {
    await _col.doc(id).update({
      'cobradorAsignado': cobradorUid,
      'cobradoresAsignados': [cobradorUid],
      if (cobradorNombre.isNotEmpty) 'cobrador': cobradorNombre,
      'fechaUltimaActualizacion': FieldValue.serverTimestamp(),
    });
  }

  /// Corrige el campo `cobrador` (nombre, DENORMALIZADO -- ver
  /// PrestamoModel) para que coincida con el nombre real de quien ya
  /// tiene asignado el préstamo en `cobradorAsignado` (el UID, que es
  /// el campo que de verdad decide quién lo ve). A PROPOSITO esta
  /// funcion NUNCA escribe `cobradorAsignado`/`cobradoresAsignados` --
  /// solo arregla el texto que se MUESTRA, nunca quién tiene acceso.
  /// Causa del bug: `reasignarCobrador` (antes de este fix) y
  /// `ClienteRepository.sincronizarAsignaciones` solo actualizaban el
  /// UID, nunca el nombre -- un prestamo reasignado por cliente quedaba
  /// viendose bien para el cobrador nuevo (el UID es el que manda) pero
  /// mostrando el nombre del cobrador VIEJO en pantalla/PDF.
  Future<int> corregirNombresCobrador(Map<String, String> nombresPorUid) async {
    final snap = await _col.get();
    var corregidos = 0;
    for (final doc in snap.docs) {
      final uid = (doc.data()['cobradorAsignado'] as String?) ?? '';
      if (uid.isEmpty) continue;
      final nombreCorrecto = nombresPorUid[uid];
      if (nombreCorrecto == null || nombreCorrecto.isEmpty) continue;
      final nombreActual = (doc.data()['cobrador'] as String?) ?? '';
      if (nombreActual == nombreCorrecto) continue;
      await doc.reference.update({'cobrador': nombreCorrecto});
      corregidos++;
    }
    return corregidos;
  }

  /// Aplica una mora al prestamo -- misma logica que DialogoAplicarMora
  /// en NotificacionesScreen.kt: incrementa saldo y mora, registra en
  /// morasAplicadas/morasIndividuales, y marca el prestamo en "mora".
  Future<void> aplicarMora(
    String id, {
    required double monto,
    required String aplicadaPor,
    required double saldoActual,
  }) async {
    final ahora = Timestamp.now();
    await _col.doc(id).update({
      'saldo': saldoActual + monto,
      'mora': FieldValue.increment(monto),
      'morasAplicadas': FieldValue.arrayUnion(['${aplicadaPor}_${ahora.millisecondsSinceEpoch}']),
      'morasIndividuales': FieldValue.arrayUnion([
        {
          'id': ahora.millisecondsSinceEpoch.toString(),
          'monto': monto,
          'fechaAplicada': ahora,
          'aplicadaPor': aplicadaPor,
          'sintetica': false,
        }
      ]),
      'estado': 'mora',
      'fechaUltimaActualizacion': ahora,
      'fechaUltimaMora': ahora,
    });
  }

  /// Cancela la mora activa del prestamo -- misma logica que el dialogo
  /// "Cancelar mora" en CuotasPrestamoScreen.kt: recalcula el saldo
  /// SIN mora (totalPagar - cuotas ya pagadas, la mora nunca fue parte
  /// de totalPagar) y deja el campo `mora` en lo que ya se pago de mora
  /// historicamente (para que la mora pendiente quede en 0, sin perder
  /// el registro de lo ya cobrado). Quita la ULTIMA entrada de
  /// `morasAplicadas` (no borra `morasIndividuales`, esas quedan como
  /// historial -- igual que el sistema viejo).
  Future<void> cancelarMora(String id) async {
    final snap = await _col.doc(id).get();
    final moraGuardada = (snap.data()?['mora'] as num?)?.toDouble() ?? 0.0;
    if (moraGuardada <= 0.0) {
      throw Exception('No hay mora activa');
    }

    final pagosSnap = await _db.collection('pagos').where('prestamoId', isEqualTo: id).get();
    var totalCuotasPagadas = 0.0;
    var totalMoraPagada = 0.0;
    for (final pago in pagosSnap.docs) {
      totalCuotasPagadas += (pago.data()['monto'] as num?)?.toDouble() ?? 0.0;
      totalMoraPagada += (pago.data()['mora'] as num?)?.toDouble() ?? 0.0;
    }

    final totalPagarBase = (snap.data()?['totalPagar'] as num?)?.toDouble() ?? 0.0;
    final nuevoSaldo = (totalPagarBase - totalCuotasPagadas).clamp(0.0, double.infinity);

    final morasAplicadasActual =
        (snap.data()?['morasAplicadas'] as List?)?.cast<String>() ?? const [];
    final morasActualizadas =
        morasAplicadasActual.isNotEmpty ? morasAplicadasActual.sublist(0, morasAplicadasActual.length - 1) : const <String>[];

    final nuevoEstado = nuevoSaldo <= 0.01 ? 'saldado' : 'activo';
    final ahora = Timestamp.now();

    final actualizacion = <String, dynamic>{
      'mora': totalMoraPagada,
      'saldo': nuevoSaldo,
      'morasAplicadas': morasActualizadas,
      'estado': nuevoEstado,
      'fechaUltimaActualizacion': ahora,
      'fechaUltimaMora': FieldValue.delete(),
    };
    if (nuevoEstado == 'saldado') {
      actualizacion['fechaSaldado'] = ahora;
      actualizacion['fechaCancelacion'] = ahora;
    }
    if (morasActualizadas.isEmpty) {
      actualizacion['saldoOriginal'] = FieldValue.delete();
    }
    await _col.doc(id).update(actualizacion);
  }

  /// Cancela UNA mora puntual (no toda la mora pendiente, a diferencia
  /// de [cancelarMora]) -- para cuando una mora especifica se aplico
  /// por equivocacion. Reduce el saldo y la mora acumulada por
  /// exactamente el monto de esa mora, y la deja marcada como
  /// cancelada en `morasIndividuales` (con quien y cuando) en vez de
  /// borrarla, para que quede el historial completo.
  Future<void> cancelarMoraIndividual(
    String id,
    String moraId, {
    required String usuarioUid,
    required String usuarioNombre,
    String descripcionPrestamo = '',
  }) async {
    final snap = await _col.doc(id).get();
    final data = snap.data();
    if (data == null) throw Exception('Préstamo no encontrado');

    final morasRaw = (data['morasIndividuales'] as List?) ?? const [];
    final moras = morasRaw
        .map((m) => MoraIndividual.fromMap(Map<String, dynamic>.from(m as Map)))
        .toList();
    final indice = moras.indexWhere((m) => m.id == moraId);
    if (indice == -1) throw Exception('Esa mora ya no existe');
    if (moras[indice].cancelada) throw Exception('Esa mora ya estaba cancelada');

    final ahora = Timestamp.now();
    final montoMora = moras[indice].monto;
    moras[indice] = moras[indice].copyWith(
      cancelada: true,
      fechaCancelada: ahora,
      canceladaPor: usuarioNombre,
    );

    final moraActual = (data['mora'] as num?)?.toDouble() ?? 0.0;
    final saldoActual = (data['saldo'] as num?)?.toDouble() ?? 0.0;
    final nuevaMora = (moraActual - montoMora).clamp(0.0, double.infinity);
    final nuevoSaldo = (saldoActual - montoMora).clamp(0.0, double.infinity);
    final quedaMoraActiva = moras.any((m) => !m.cancelada);
    final nuevoEstado = nuevoSaldo <= 0.01 ? 'saldado' : (quedaMoraActiva ? 'mora' : 'activo');

    await _col.doc(id).update({
      'morasIndividuales': moras.map((m) => m.toMap()).toList(),
      'mora': nuevaMora,
      'saldo': nuevoSaldo,
      'estado': nuevoEstado,
      'fechaUltimaActualizacion': ahora,
    });

    BitacoraRepository().registrar(
      accion: 'cancelar_mora',
      entidadTipo: 'prestamo',
      descripcion:
          '${descripcionPrestamo.isNotEmpty ? descripcionPrestamo : 'Préstamo (ID: $id)'} - mora de ${montoMora.toStringAsFixed(2)}',
      usuarioUid: usuarioUid,
      usuarioNombre: usuarioNombre,
    );
  }

  /// Cantidad de prestamos en mora (para el stat "Pagos Tarde").
  Future<int> contarEnMora({String? cobradorUid}) async {
    Query<Map<String, dynamic>> query = _col.where('estado', isEqualTo: 'mora');
    if (cobradorUid != null) {
      query = query.where('cobradoresAsignados', arrayContains: cobradorUid);
    }
    final agg = await query.count().get();
    return agg.count ?? 0;
  }

  /// Suma del saldo pendiente de todos los prestamos no eliminados (para
  /// el stat "Pendiente"). Se agrega en el servidor, no se descargan
  /// los documentos.
  Future<double> sumarSaldoPendiente({String? cobradorUid}) async {
    Query<Map<String, dynamic>> query = _col.where('eliminado', isEqualTo: false);
    if (cobradorUid != null) {
      query = query.where('cobradoresAsignados', arrayContains: cobradorUid);
    }
    final agg = await query.aggregate(sum('saldo')).get();
    return (agg.getSum('saldo') ?? 0).toDouble();
  }

  /// Total prestado (monto) e interes total sobre TODOS los prestamos
  /// (sin filtro de fecha, igual que DashboardScreen.kt) -- agregado en
  /// el servidor, no se descarga ningun documento.
  Future<({double monto, double interes})> sumarMontoEInteres() async {
    final agg = await _col.aggregate(sum('monto'), sum('interesTotal')).get();
    return (
      monto: (agg.getSum('monto') ?? 0).toDouble(),
      interes: (agg.getSum('interesTotal') ?? 0).toDouble(),
    );
  }

  Future<String> crear(Map<String, dynamic> datos) async {
    final docRef = _col.doc();
    await docRef.set({
      ...datos,
      'id': docRef.id,
      'prestamoId': docRef.id,
      'fechaCreacion': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<void> actualizar(
    String id,
    Map<String, dynamic> datos, {
    required String usuarioUid,
    required String usuarioNombre,
    String descripcionPrestamo = '',
  }) async {
    await _col.doc(id).update({
      ...datos,
      'fechaUltimaActualizacion': FieldValue.serverTimestamp(),
    });
    BitacoraRepository().registrar(
      accion: 'editar_prestamo',
      entidadTipo: 'prestamo',
      descripcion: descripcionPrestamo.isNotEmpty ? descripcionPrestamo : 'Préstamo (ID: $id)',
      usuarioUid: usuarioUid,
      usuarioNombre: usuarioNombre,
    );
  }

  Future<void> marcarEliminado(
    String id, {
    required String eliminadoPor,
    required String usuarioUid,
    String descripcionPrestamo = '',
  }) async {
    await _col.doc(id).update({
      'eliminado': true,
      'eliminadoPor': eliminadoPor,
      'fechaUltimaActualizacion': FieldValue.serverTimestamp(),
    });
    BitacoraRepository().registrar(
      accion: 'eliminar_prestamo',
      entidadTipo: 'prestamo',
      descripcion: descripcionPrestamo.isNotEmpty ? descripcionPrestamo : 'Préstamo (ID: $id)',
      usuarioUid: usuarioUid,
      usuarioNombre: eliminadoPor,
    );
  }

  Future<void> restaurar(
    String id, {
    required String usuarioUid,
    required String usuarioNombre,
    String descripcionPrestamo = '',
  }) async {
    await _col.doc(id).update({
      'eliminado': false,
      'eliminadoPor': FieldValue.delete(),
      'fechaUltimaActualizacion': FieldValue.serverTimestamp(),
    });
    BitacoraRepository().registrar(
      accion: 'restaurar_prestamo',
      entidadTipo: 'prestamo',
      descripcion: descripcionPrestamo.isNotEmpty ? descripcionPrestamo : 'Préstamo (ID: $id)',
      usuarioUid: usuarioUid,
      usuarioNombre: usuarioNombre,
    );
  }

  /// Borra el documento de verdad (a diferencia de marcarEliminado, que
  /// es un soft-delete). Se usa desde el modo "Ver eliminados" para
  /// purgar definitivamente.
  Future<void> eliminarPermanente(
    String id, {
    required String usuarioUid,
    required String usuarioNombre,
    String descripcionPrestamo = '',
  }) async {
    await _col.doc(id).delete();
    BitacoraRepository().registrar(
      accion: 'eliminar_prestamo_permanente',
      entidadTipo: 'prestamo',
      descripcion: descripcionPrestamo.isNotEmpty ? descripcionPrestamo : 'Préstamo (ID: $id)',
      usuarioUid: usuarioUid,
      usuarioNombre: usuarioNombre,
    );
  }

  /// Purga TODOS los prestamos ya marcados como eliminados (soft-delete)
  /// del alcance dado. Usa batches de 400 escrituras (limite de Firestore
  /// es 500 por batch).
  Future<int> eliminarTodosLosEliminados({
    String? cobradorUid,
    required String usuarioUid,
    required String usuarioNombre,
  }) async {
    Query<Map<String, dynamic>> query = _col.where('eliminado', isEqualTo: true);
    if (cobradorUid != null) {
      query = query.where('cobradoresAsignados', arrayContains: cobradorUid);
    }
    final snap = await query.get();
    var borrados = 0;
    for (var i = 0; i < snap.docs.length; i += 400) {
      final lote = snap.docs.skip(i).take(400);
      final batch = _db.batch();
      for (final doc in lote) {
        batch.delete(doc.reference);
        borrados++;
      }
      await batch.commit();
    }
    if (borrados > 0) {
      BitacoraRepository().registrar(
        accion: 'eliminar_prestamo_permanente',
        entidadTipo: 'prestamo',
        descripcion: 'Purga masiva: $borrados préstamo(s) eliminados definitivamente',
        usuarioUid: usuarioUid,
        usuarioNombre: usuarioNombre,
      );
    }
    return borrados;
  }
}
