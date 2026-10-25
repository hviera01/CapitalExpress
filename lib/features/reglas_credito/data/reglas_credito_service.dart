import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/models/cliente_model.dart';
import '../../../core/models/pago_model.dart';
import '../../../core/models/prestamo_model.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/reglas_credito.dart';
import '../../../core/utils/reglas_credito.dart' as reglas show validarNuevoPrestamo;
import '../../bitacora/data/bitacora_repository.dart';
import '../../pagos/data/pago_repository.dart';
import '../../prestamos/data/prestamo_repository.dart';

class EventoCredito {
  final String id;
  final String clienteId;
  final String clienteNombre;
  final String tipo;
  final String titulo;
  final String anterior;
  final String nuevo;
  final List<String> motivo;
  final DateTime? fecha;
  final String origen;
  final String usuario;

  const EventoCredito({
    required this.id,
    required this.clienteId,
    required this.clienteNombre,
    required this.tipo,
    required this.titulo,
    required this.anterior,
    required this.nuevo,
    required this.motivo,
    required this.fecha,
    required this.origen,
    required this.usuario,
  });

  factory EventoCredito.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    String s(String k) => (d[k] ?? '') as String;
    return EventoCredito(
      id: doc.id,
      clienteId: s('clienteId'),
      clienteNombre: s('clienteNombre'),
      tipo: s('tipo'),
      titulo: s('titulo'),
      anterior: s('anterior'),
      nuevo: s('nuevo'),
      motivo: (d['motivo'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      fecha: (d['fecha'] as Timestamp?)?.toDate(),
      origen: s('origen'),
      usuario: s('usuario'),
    );
  }
}

class ResultadoRecalculo {
  final int clientes;
  final int categoriaA;
  final int categoriaB;
  final int categoriaC;
  final int eventos;

  const ResultadoRecalculo({
    required this.clientes,
    required this.categoriaA,
    required this.categoriaB,
    required this.categoriaC,
    required this.eventos,
  });
}

class ReglasCreditoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final PrestamoRepository _prestamos = PrestamoRepository();
  final PagoRepository _pagos = PagoRepository();

  static const _coleccionEventos = 'eventos_credito';
  static const _docControl = 'evaluacion_credito';

  double? _tasaAsignada(Map<String, dynamic> datos) => (datos['tasaPreferencialPct'] as num?)?.toDouble();

  DateTime? _tasaDesde(Map<String, dynamic> datos) => (datos['tasaPreferencialDesde'] as Timestamp?)?.toDate();

  bool _tasaGeneralForzada(Map<String, dynamic> datos) => datos['tasaGeneralForzada'] == true;

  Future<EvaluacionCredito?> evaluacionAlmacenada(String clienteId) async {
    final doc = await _db.collection('clientes').doc(clienteId).get();
    final datos = doc.data();
    if (datos == null) return null;
    return EvaluacionCredito.desdeAlmacenado(datos);
  }

  Future<EvaluacionCredito> evaluarCliente(
    String clienteId, {
    DateTime? hoy,
    Map<String, dynamic>? datosCliente,
  }) async {
    final futuroDatos = datosCliente != null
        ? Future.value(datosCliente)
        : _db.collection('clientes').doc(clienteId).get().then((d) => d.data() ?? const <String, dynamic>{});
    final resultados = await Future.wait<Object>([futuroDatos, _prestamos.obtenerPorCliente(clienteId)]);
    final datos = resultados[0] as Map<String, dynamic>;
    final prestamos = resultados[1] as List<PrestamoModel>;
    final pagos = await _pagos.obtenerPorPrestamos(prestamos.map((p) => p.prestamoId).toList());
    return evaluarCredito(
      prestamos: prestamos,
      pagosPorPrestamo: pagos,
      hoy: hoy ?? DateTime.now(),
      tasaPreferencialAsignada: _tasaAsignada(datos),
      tasaPreferencialDesde: _tasaDesde(datos),
      tasaGeneralForzada: _tasaGeneralForzada(datos),
    );
  }

  Future<String?> motivoPrestamoActivoExterno(
    ClienteModel cliente, {
    String? excluirSolicitudId,
  }) async {
    final identidad = cliente.identidad.trim();
    if (identidad.isNotEmpty) {
      final fichas = await _db.collection('clientes').where('identidad', isEqualTo: identidad).get();
      for (final ficha in fichas.docs) {
        if (ficha.id == cliente.id) continue;
        if (await _prestamos.tienePrestamoActivo(ficha.id)) {
          final nombre = (ficha.data()['nombre'] ?? '') as String;
          return 'La identidad $identidad ya tiene un préstamo activo en la ficha "$nombre".';
        }
      }
    }
    final pendientes = await _db
        .collection('solicitudes_prestamo')
        .where('clienteId', isEqualTo: cliente.id)
        .where('estado', isEqualTo: 'pendiente')
        .get();
    final hayOtra = pendientes.docs.any((d) => d.id != excluirSolicitudId);
    if (hayOtra) return 'El cliente ya tiene una solicitud de préstamo pendiente de aprobación.';
    return null;
  }

  Future<List<ViolacionCredito>> validarNuevoPrestamo({
    required ClienteModel cliente,
    required double totalAPagar,
    required double interesMensualPct,
    String? excluirSolicitudId,
  }) async {
    final resultados = await Future.wait<Object?>([
      evaluarCliente(cliente.id),
      motivoPrestamoActivoExterno(cliente, excluirSolicitudId: excluirSolicitudId),
    ]);
    return reglas.validarNuevoPrestamo(
      evaluacion: resultados[0] as EvaluacionCredito,
      totalAPagar: totalAPagar,
      interesMensualPct: interesMensualPct,
      prestamoActivoExterno: resultados[1] as String?,
    );
  }

  Future<List<ClienteModel>> buscarPorIdentidad(String texto, {String? cobradorUid}) async {
    final crudo = texto.trim();
    final digitos = crudo.replaceAll(RegExp(r'\D'), '');
    if (digitos.isEmpty) return const [];
    final variantes = <String>{
      crudo,
      digitos,
      if (digitos.length == 13) '${digitos.substring(0, 4)}-${digitos.substring(4, 8)}-${digitos.substring(8)}',
    }.where((v) => v.isNotEmpty).toList();
    final snap = await _db.collection('clientes').where('identidad', whereIn: variantes).get();
    final resultado = <ClienteModel>[];
    for (final doc in snap.docs) {
      if (cobradorUid != null) {
        final datos = doc.data();
        final asignados = (datos['cobradoresAsignados'] as List?)?.map((e) => e.toString()).toList() ?? const [];
        if (!asignados.contains(cobradorUid) && datos['cobradorAsignado'] != cobradorUid) continue;
      }
      try {
        resultado.add(ClienteModel.fromDoc(doc));
      } catch (_) {}
    }
    return resultado;
  }

  Future<EvaluacionCredito?> evaluarYPersistir(
    String clienteId, {
    required String origen,
    String usuario = '',
  }) async {
    final doc = await _db.collection('clientes').doc(clienteId).get();
    if (!doc.exists) return null;
    final datos = doc.data() ?? const <String, dynamic>{};
    final evaluacion = await evaluarCliente(clienteId, datosCliente: datos);
    unawaited(_persistir(
      clienteId: clienteId,
      clienteNombre: (datos['nombre'] ?? '') as String,
      evaluacion: evaluacion,
      almacenado: datos,
      origen: origen,
      usuario: usuario,
    ).then((_) => 0).catchError((_) => 0));
    return evaluacion;
  }

  void evaluarDespuesDe(
    String clienteId, {
    required String origen,
    String usuario = '',
    Duration espera = const Duration(milliseconds: 500),
  }) {
    Future<void>.delayed(espera, () async {
      try {
        await evaluarYPersistir(clienteId, origen: origen, usuario: usuario);
      } catch (_) {}
    });
  }

  Future<void> asignarTasaPreferencial({
    required String clienteId,
    required String clienteNombre,
    required double? pct,
    required String usuarioUid,
    required String usuarioNombre,
    String nota = '',
  }) async {
    final ref = _db.collection('clientes').doc(clienteId);
    final anterior = (await ref.get()).data() ?? const <String, dynamic>{};
    final eraPref = (anterior['tasaTipo'] ?? '') == 'preferencial';

    await ref.update(pct == null
        ? {
            'tasaPreferencialPct': FieldValue.delete(),
            'tasaPreferencialDesde': FieldValue.serverTimestamp(),
            'tasaGeneralForzada': true,
          }
        : {
            'tasaPreferencialPct': pct,
            'tasaPreferencialDesde': FieldValue.serverTimestamp(),
            'tasaGeneralForzada': FieldValue.delete(),
          });

    final datosNuevos = (await ref.get()).data() ?? const <String, dynamic>{};
    final evaluacion = await evaluarCliente(clienteId, datosCliente: datosNuevos);
    await _persistir(
      clienteId: clienteId,
      clienteNombre: clienteNombre,
      evaluacion: evaluacion,
      almacenado: datosNuevos,
      origen: 'administracion',
      usuario: usuarioNombre,
      generarEventos: false,
    );

    final titulo = pct == null
        ? 'Administración quitó la tasa preferencial: vuelve a la tasa general del ${tasaGeneralPct.toStringAsFixed(0)}%'
        : 'Administración asignó tasa preferencial de ${pct.toStringAsFixed(pct == pct.roundToDouble() ? 0 : 2)}%';
    await _db.collection(_coleccionEventos).add({
      'clienteId': clienteId,
      'clienteNombre': clienteNombre,
      'tipo': 'tasa',
      'titulo': titulo,
      'anterior': eraPref ? 'preferencial' : 'general',
      'nuevo': pct == null ? 'general' : 'preferencial',
      'motivo': [
        'Cambio hecho manualmente por $usuarioNombre (administración).',
        if (pct == null) 'Se mantendrá en tasa general hasta que administración le asigne otra.',
        if (nota.trim().isNotEmpty) 'Motivo indicado: ${nota.trim().toUpperCase()}',
        if (pct != null) 'Si en un préstamo posterior se atrasa en 2 pagos, la perderá automáticamente.',
      ],
      'fecha': FieldValue.serverTimestamp(),
      'origen': 'administracion',
      'usuario': usuarioNombre,
    });
    BitacoraRepository().registrar(
      accion: 'asignar_tasa_preferencial',
      entidadTipo: 'cliente',
      descripcion: '$clienteNombre: $titulo',
      usuarioUid: usuarioUid,
      usuarioNombre: usuarioNombre,
    );
  }

  List<Map<String, dynamic>> _detectarCambios(
    Map<String, dynamic> almacenado,
    EvaluacionCredito e,
  ) {
    final eventos = <Map<String, dynamic>>[];

    final catAnterior = (almacenado['categoriaCredito'] ?? '') as String;
    final catNueva = e.categoria.letra;
    if (catAnterior != catNueva) {
      eventos.add({
        'tipo': 'categoria',
        'titulo': catAnterior.isEmpty
            ? 'Categoría inicial: $catNueva'
            : 'Cambió de categoría $catAnterior a $catNueva',
        'anterior': catAnterior,
        'nuevo': catNueva,
        'motivo': e.motivoCategoria,
      });
    }

    final tasaAnterior = (almacenado['tasaTipo'] ?? '') as String;
    final perdioAntes = almacenado['perdioTasaPreferencial'] == true;
    final tasaNueva = e.tasaTipo;
    if (e.perdioTasaPreferencial && !perdioAntes) {
      eventos.add({
        'tipo': 'tasa',
        'titulo': 'Perdió la tasa preferencial: pasa a tasa general del ${tasaGeneralPct.toStringAsFixed(0)}%',
        'anterior': tasaAnterior.isEmpty ? 'preferencial' : tasaAnterior,
        'nuevo': 'general',
        'motivo': e.motivoTasa,
      });
    } else if (tasaAnterior != tasaNueva && !(tasaAnterior.isEmpty && tasaNueva == 'general')) {
      eventos.add({
        'tipo': 'tasa',
        'titulo': tasaAnterior.isEmpty
            ? 'Tasa inicial: $tasaNueva'
            : 'Cambió de tasa $tasaAnterior a $tasaNueva',
        'anterior': tasaAnterior,
        'nuevo': tasaNueva,
        'motivo': e.motivoTasa,
      });
    }

    final incrementoAntes = almacenado['incrementoElegible'] == true;
    var huboEventoIncremento = false;
    if (incrementoAntes != e.incrementoElegible) {
      huboEventoIncremento = true;
      eventos.add({
        'tipo': 'incremento',
        'titulo': e.incrementoElegible
            ? 'Ahora aplica a incremento del ${(incrementoPermitido * 100).round()}%'
            : 'Ya no aplica a incremento',
        'anterior': incrementoAntes ? 'aplica' : 'no aplica',
        'nuevo': e.incrementoElegible ? 'aplica' : 'no aplica',
        'motivo': e.motivoIncremento,
      });
    }

    final maxAntes = (almacenado['totalMaximoCredito'] as num?)?.toDouble();
    final maxNuevo = e.totalMaximo;
    final cambioMax = (maxAntes == null) != (maxNuevo == null) ||
        (maxAntes != null && maxNuevo != null && (maxAntes - maxNuevo).abs() > 0.01);
    if (cambioMax && maxNuevo != null && !huboEventoIncremento) {
      eventos.add({
        'tipo': 'monto',
        'titulo': 'Total a pagar máximo para su próximo préstamo: ${formatearLempiras(maxNuevo)}',
        'anterior': maxAntes == null ? '' : formatearLempiras(maxAntes),
        'nuevo': formatearLempiras(maxNuevo),
        'motivo': [...e.motivoMonto, ...e.motivoIncremento],
      });
    }

    return eventos;
  }

  Future<int> _persistir({
    required String clienteId,
    required String clienteNombre,
    required EvaluacionCredito evaluacion,
    required Map<String, dynamic> almacenado,
    required String origen,
    required String usuario,
    WriteBatch? lote,
    bool generarEventos = true,
  }) async {
    final cambios = generarEventos ? _detectarCambios(almacenado, evaluacion) : const <Map<String, dynamic>>[];
    final esquemaViejo = !almacenado.containsKey('prestamoActivoCredito');
    final cambioEstado = cambios.isNotEmpty ||
        esquemaViejo ||
        (almacenado['categoriaCredito'] ?? '') != evaluacion.categoria.letra ||
        (almacenado['tasaTipo'] ?? '') != evaluacion.tasaTipo ||
        (almacenado['prestamoActivoCredito'] == true) != evaluacion.tienePrestamoActivo ||
        (almacenado['incrementoElegible'] == true) != evaluacion.incrementoElegible ||
        (almacenado['limitePorVencimiento'] == true) != evaluacion.limitePorVencimiento ||
        (almacenado['perdioTasaPreferencial'] == true) != evaluacion.perdioTasaPreferencial;
    if (!cambioEstado) return 0;

    final batch = lote ?? _db.batch();
    final clienteRef = _db.collection('clientes').doc(clienteId);
    batch.update(clienteRef, {
      ...evaluacion.aMapaPersistido(),
      'evaluacionCreditoFecha': FieldValue.serverTimestamp(),
      if (evaluacion.perdioTasaPreferencial && almacenado['tasaPreferencialPct'] != null) ...{
        'tasaPreferencialPct': FieldValue.delete(),
        'tasaPreferencialDesde': FieldValue.delete(),
      },
    });
    for (final c in cambios) {
      batch.set(_db.collection(_coleccionEventos).doc(), {
        'clienteId': clienteId,
        'clienteNombre': clienteNombre,
        ...c,
        'fecha': FieldValue.serverTimestamp(),
        'origen': origen,
        'usuario': usuario,
      });
    }
    if (lote == null) await batch.commit();
    return cambios.length;
  }

  Future<void> registrarExcepcion({
    required String clienteId,
    required String clienteNombre,
    required List<String> motivos,
    required String usuario,
    String titulo = 'Autorización especial aprobada',
  }) async {
    await _db.collection(_coleccionEventos).add({
      'clienteId': clienteId,
      'clienteNombre': clienteNombre,
      'tipo': 'excepcion',
      'titulo': '$titulo por $usuario',
      'anterior': '',
      'nuevo': '',
      'motivo': motivos,
      'fecha': FieldValue.serverTimestamp(),
      'origen': 'excepcion',
      'usuario': usuario,
    });
  }

  Future<List<EventoCredito>> obtenerEventos(String clienteId) async {
    final snap = await _db.collection(_coleccionEventos).where('clienteId', isEqualTo: clienteId).get();
    final lista = snap.docs.map(EventoCredito.fromDoc).toList()
      ..sort((a, b) => (b.fecha ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.fecha ?? DateTime.fromMillisecondsSinceEpoch(0)));
    return lista;
  }

  Stream<List<EventoCredito>> streamEventos(String clienteId) {
    return _db.collection(_coleccionEventos).where('clienteId', isEqualTo: clienteId).snapshots().map((snap) {
      final lista = snap.docs.map(EventoCredito.fromDoc).toList()
        ..sort((a, b) => (b.fecha ?? DateTime.now()).compareTo(a.fecha ?? DateTime.now()));
      return lista;
    });
  }

  Future<ResultadoRecalculo> recalcularTodos({
    String usuario = '',
    String origen = 'recalculo',
    void Function(String)? avance,
  }) async {
    avance?.call('Leyendo clientes y préstamos...');
    final clientesSnap = await _db.collection('clientes').get();
    final prestamosSnap = await _db.collection('prestamos').get();

    final prestamosPorCliente = <String, List<PrestamoModel>>{};
    for (final doc in prestamosSnap.docs) {
      try {
        final p = PrestamoModel.fromDoc(doc);
        if (p.eliminado || p.clienteId.isEmpty) continue;
        (prestamosPorCliente[p.clienteId] ??= []).add(p);
      } catch (_) {}
    }

    avance?.call('Leyendo pagos...');
    final ids = prestamosPorCliente.values.expand((l) => l.map((p) => p.prestamoId)).toList();
    final pagos = await _pagos.obtenerPorPrestamos(ids);

    avance?.call('Evaluando ${clientesSnap.docs.length} clientes...');
    final hoy = DateTime.now();
    var a = 0, b = 0, c = 0, eventos = 0;
    var batch = _db.batch();
    var operaciones = 0;

    Future<void> volcar() async {
      if (operaciones == 0) return;
      await batch.commit();
      batch = _db.batch();
      operaciones = 0;
    }

    for (final doc in clientesSnap.docs) {
      final datos = doc.data();
      final prestamos = prestamosPorCliente[doc.id] ?? const <PrestamoModel>[];
      final Map<String, List<PagoModel>> pagosCliente = {
        for (final p in prestamos) p.prestamoId: pagos[p.prestamoId] ?? const [],
      };
      final evaluacion = evaluarCredito(
        prestamos: prestamos,
        pagosPorPrestamo: pagosCliente,
        hoy: hoy,
        tasaPreferencialAsignada: _tasaAsignada(datos),
        tasaPreferencialDesde: _tasaDesde(datos),
        tasaGeneralForzada: _tasaGeneralForzada(datos),
      );
      switch (evaluacion.categoria) {
        case CategoriaCredito.a:
          a++;
        case CategoriaCredito.b:
          b++;
        case CategoriaCredito.c:
          c++;
      }
      final n = await _persistir(
        clienteId: doc.id,
        clienteNombre: (datos['nombre'] ?? '') as String,
        evaluacion: evaluacion,
        almacenado: datos,
        origen: origen,
        usuario: usuario,
        lote: batch,
      );
      eventos += n;
      operaciones += 1 + n;
      if (operaciones >= 400) await volcar();
    }
    await volcar();

    await _db.collection('configuracion').doc(_docControl).set({
      'ultimaCorrida': FieldValue.serverTimestamp(),
      'clientes': clientesSnap.docs.length,
    }, SetOptions(merge: true));

    return ResultadoRecalculo(
      clientes: clientesSnap.docs.length,
      categoriaA: a,
      categoriaB: b,
      categoriaC: c,
      eventos: eventos,
    );
  }

  Future<ResultadoRecalculo?> recalcularSiHaceFalta({
    String usuario = '',
    Duration cadaCuanto = const Duration(hours: 20),
  }) async {
    final ref = _db.collection('configuracion').doc(_docControl);
    final doc = await ref.get();
    final ultima = (doc.data()?['ultimaCorrida'] as Timestamp?)?.toDate();
    if (ultima != null && DateTime.now().difference(ultima) < cadaCuanto) return null;
    await ref.set({'ultimaCorrida': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    return recalcularTodos(usuario: usuario, origen: 'automatico');
  }
}
