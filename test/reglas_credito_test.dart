import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:capital_express/core/models/pago_model.dart';
import 'package:capital_express/core/models/prestamo_model.dart';
import 'package:capital_express/core/utils/reglas_credito.dart';

PrestamoModel _prestamo({
  required String id,
  required DateTime inicio,
  double monto = 10000,
  double tasa = 15,
  int cuotas = 4,
  String plazo = 'Semanal',
  bool saldado = true,
  bool usarInteresMensual = true,
}) {
  final total = monto * 1.2;
  return PrestamoModel(
    prestamoId: id,
    numeroPrestamo: id,
    clienteId: 'c1',
    cliente: 'CLIENTE',
    monto: monto,
    totalPagar: total,
    cuota: (total / cuotas).roundToDouble(),
    cuotas: cuotas,
    plazo: plazo,
    interesMensual: tasa,
    usarInteresMensual: usarInteresMensual,
    saldo: saldado ? 0 : total,
    estado: saldado ? 'saldado' : 'activo',
    fecha: Timestamp.fromDate(inicio),
  );
}

PagoModel _pago(String prestamoId, double monto, DateTime fecha, {int n = 0}) => PagoModel(
    docId: 'p$prestamoId$n${fecha.millisecondsSinceEpoch}',
    prestamoId: prestamoId,
    monto: monto,
    fechaPago: Timestamp.fromDate(fecha));

List<PagoModel> _pagosATiempo(PrestamoModel p) {
  final inicio = p.fecha!.toDate();
  return [
    for (var n = 1; n <= p.cuotas; n++)
      _pago(p.prestamoId, p.cuota, inicio.add(Duration(days: 7 * n)), n: n),
  ];
}

List<PagoModel> _pagosEnFechas(PrestamoModel p, List<DateTime> fechas) => [
      for (var i = 0; i < fechas.length; i++) _pago(p.prestamoId, p.cuota, fechas[i], n: i + 1),
    ];

EvaluacionCredito _eval(
  List<PrestamoModel> prestamos,
  Map<String, List<PagoModel>> pagos,
  DateTime hoy, {
  double? asignada,
  DateTime? desde,
  bool forzadaGeneral = false,
}) =>
    evaluarCredito(
      prestamos: prestamos,
      pagosPorPrestamo: pagos,
      hoy: hoy,
      tasaPreferencialAsignada: asignada,
      tasaPreferencialDesde: desde,
      tasaGeneralForzada: forzadaGeneral,
    );

List<ViolacionCredito> _validar(EvaluacionCredito e, double total,
        {double tasa = 15, String? externo}) =>
    validarNuevoPrestamo(
      evaluacion: e,
      totalAPagar: total,
      interesMensualPct: tasa,
      prestamoActivoExterno: externo,
    );

void main() {
  final hoy = DateTime(2027, 6, 1);

  group('Atraso por cuota y categorías', () {
    test('paga todo a tiempo -> categoría A, sin atrasos', () {
      final p = _prestamo(id: 'P1', inicio: DateTime(2026, 10, 5));
      final e = _eval([p], {'P1': _pagosATiempo(p)}, hoy);
      expect(e.categoria, CategoriaCredito.a);
      expect(e.ultimo!.cuotasAtrasadas, 0);
    });

    test('paga adelantado -> categoría A y el motivo lo dice como cliente puntual', () {
      final p = _prestamo(id: 'P1', inicio: DateTime(2026, 10, 5));
      final e = _eval([p], {'P1': [_pago('P1', p.totalPagar, DateTime(2026, 10, 6))]}, hoy);
      expect(e.categoria, CategoriaCredito.a);
      expect(e.motivoCategoria.join(' '), contains('Cliente puntual'));
      expect(e.motivoCategoria.join(' '), contains('antes de sus fechas'));
      expect(e.motivoCategoria.join(' '), isNot(contains('vencidas')));
    });

    test('paga en la fecha exacta -> cliente al día', () {
      final p = _prestamo(id: 'P1', inicio: DateTime(2026, 10, 5));
      final e = _eval([p], {'P1': _pagosATiempo(p)}, hoy);
      expect(e.motivoCategoria.join(' '), contains('Cliente al día'));
      expect(e.motivoCategoria.join(' '), contains('en la fecha que le toca'));
    });

    test('1 día de atraso cuenta como 1 semana -> categoría B', () {
      final p = _prestamo(id: 'P1', inicio: DateTime(2026, 10, 5));
      final pagos = _pagosATiempo(p);
      pagos[0] = _pago('P1', p.cuota, DateTime(2026, 10, 13), n: 1);
      final e = _eval([p], {'P1': pagos}, hoy);
      expect(e.ultimo!.cuotas[0].diasAtraso, 1);
      expect(e.ultimo!.cuotas[0].semanasAtraso, 1);
      expect(e.categoria, CategoriaCredito.b);
    });

    test('14 días de atraso = 2 semanas -> categoría B', () {
      final p = _prestamo(id: 'P1', inicio: DateTime(2026, 10, 5));
      final pagos = _pagosEnFechas(p, [
        DateTime(2026, 10, 26),
        DateTime(2026, 10, 26),
        DateTime(2026, 10, 26),
        DateTime(2026, 11, 2)
      ]);
      final e = _eval([p], {'P1': pagos}, hoy);
      expect(e.ultimo!.cuotas[0].diasAtraso, 14);
      expect(e.ultimo!.cuotas[0].semanasAtraso, 2);
      expect(e.categoria, CategoriaCredito.b);
    });

    test('15 días de atraso = 3 semanas -> categoría C', () {
      final p = _prestamo(id: 'P1', inicio: DateTime(2026, 10, 5));
      final pagos = _pagosEnFechas(p, [
        DateTime(2026, 10, 27),
        DateTime(2026, 10, 27),
        DateTime(2026, 10, 27),
        DateTime(2026, 11, 2)
      ]);
      final e = _eval([p], {'P1': pagos}, hoy);
      expect(e.ultimo!.cuotas[0].diasAtraso, 15);
      expect(e.ultimo!.cuotas[0].semanasAtraso, 3);
      expect(e.categoria, CategoriaCredito.c);
    });

    test('cuota vencida sin pagar cuenta atraso contra hoy (préstamo activo)', () {
      final p = _prestamo(id: 'P1', inicio: DateTime(2026, 10, 5), saldado: false);
      final e = _eval([p], {'P1': const []}, DateTime(2026, 11, 3));
      final c = e.ultimo!.cuotas;
      expect(c[0].pagada, false);
      expect(c[0].diasAtraso, 22);
      expect(c[3].diasAtraso, 1);
      expect(e.categoria, CategoriaCredito.c);
      expect(e.tienePrestamoActivo, true);
    });

    test('el día exacto del vencimiento todavía no es atraso', () {
      final p = _prestamo(id: 'P1', inicio: DateTime(2026, 10, 5), saldado: false);
      final e = _eval([p], {'P1': const []}, DateTime(2026, 10, 12));
      expect(e.ultimo!.cuotas[0].diasAtraso, 0);
      expect(e.categoria, CategoriaCredito.a);
      expect(e.motivoCategoria.join(' '), contains('Cliente al día'));
    });

    test('el motivo de la categoría detalla cada pago atrasado con lenguaje claro', () {
      final p = _prestamo(id: 'P1', inicio: DateTime(2026, 10, 5));
      final pagos = _pagosATiempo(p);
      pagos[1] = _pago('P1', p.cuota, DateTime(2026, 10, 30), n: 2);
      final e = _eval([p], {'P1': pagos}, hoy);
      final texto = e.motivoCategoria.join('\n');
      expect(texto, contains('Cuota 2'));
      expect(texto, contains('le tocaba pagar el 19/10/2026'));
      expect(texto, contains('pagó el 30/10/2026'));
      expect(texto, contains('Categoría B'));
      expect(texto, isNot(contains('vencidas')));
    });

    test('cliente sin préstamos nace en categoría A y tasa general', () {
      final e = _eval([], {}, hoy);
      expect(e.categoria, CategoriaCredito.a);
      expect(e.tasaTipo, 'general');
      expect(e.totalMaximo, isNull);
      expect(e.motivoCategoria.join(' '), contains('Cliente nuevo'));
    });

    test('préstamos eliminados no cuentan', () {
      final p = _prestamo(id: 'P1', inicio: DateTime(2026, 10, 5));
      final eliminado = PrestamoModel(
          prestamoId: 'X',
          eliminado: true,
          monto: 5,
          cuotas: 1,
          plazo: 'Semanal',
          fecha: Timestamp.fromDate(DateTime(2027, 1, 1)),
          saldo: 5);
      final e = _eval([p, eliminado], {'P1': _pagosATiempo(p)}, hoy);
      expect(e.ciclos.length, 1);
      expect(e.tienePrestamoActivo, false);
    });
  });

  group('Regla 1: tasa preferencial', () {
    test('tasa preferencial y 2 cuotas atrasadas acumuladas -> la pierde', () {
      final p = _prestamo(id: 'P1', inicio: DateTime(2026, 10, 5), tasa: 10);
      final pagos = _pagosEnFechas(p, [
        DateTime(2026, 10, 12),
        DateTime(2026, 10, 27),
        DateTime(2026, 10, 27),
        DateTime(2026, 11, 2)
      ]);
      final e = _eval([p], {'P1': pagos}, hoy);
      expect(e.ultimo!.cuotasAtrasadas, 2);
      expect(e.perdioTasaPreferencial, true);
      expect(e.tasaMinimaPct, 15);
      expect(e.tasaTipo, 'general');
      expect(e.motivoTasa.join(' '), contains('Pierde la tasa preferencial'));
    });

    test('2 cuotas atrasadas intercaladas también la pierde', () {
      final p = _prestamo(id: 'P1', inicio: DateTime(2026, 10, 5), tasa: 12);
      final pagos = [
        _pago('P1', p.cuota, DateTime(2026, 10, 14), n: 1),
        _pago('P1', p.cuota, DateTime(2026, 10, 19), n: 2),
        _pago('P1', p.cuota, DateTime(2026, 10, 29), n: 3),
        _pago('P1', p.cuota, DateTime(2026, 11, 2), n: 4),
      ];
      final e = _eval([p], {'P1': pagos}, hoy);
      expect(e.ultimo!.cuotas.map((c) => c.atrasada).toList(), [true, false, true, false]);
      expect(e.perdioTasaPreferencial, true);
    });

    test('solo 1 cuota atrasada -> conserva la preferencial', () {
      final p = _prestamo(id: 'P1', inicio: DateTime(2026, 10, 5), tasa: 10);
      final pagos = _pagosATiempo(p);
      pagos[0] = _pago('P1', p.cuota, DateTime(2026, 10, 14), n: 1);
      final e = _eval([p], {'P1': pagos}, hoy);
      expect(e.perdioTasaPreferencial, false);
      expect(e.tasaTipo, 'preferencial');
      expect(e.tasaVigentePct, 10);
      expect(e.tasaMinimaPct, 10);
    });

    test('tasa general (15) con muchos atrasos no pierde nada y sigue general', () {
      final p = _prestamo(id: 'P1', inicio: DateTime(2026, 10, 5), tasa: 15, saldado: false);
      final e = _eval([p], {'P1': const []}, DateTime(2026, 12, 1));
      expect(e.perdioTasaPreferencial, false);
      expect(e.tuvoTasaPreferencial, false);
      expect(e.tasaTipo, 'general');
    });

    test('préstamo activo con 2 cuotas ya vencidas sin pagar también la pierde', () {
      final p = _prestamo(id: 'P1', inicio: DateTime(2026, 10, 5), tasa: 8, saldado: false);
      final e = _eval([p], {'P1': const []}, DateTime(2026, 10, 21));
      expect(e.ultimo!.cuotasAtrasadas, 2);
      expect(e.perdioTasaPreferencial, true);
    });

    test('validación: tasa menor a 15 prohibida si la perdió', () {
      final p = _prestamo(id: 'P1', inicio: DateTime(2026, 10, 5), tasa: 10);
      final pagos = _pagosEnFechas(p, [
        DateTime(2026, 10, 14),
        DateTime(2026, 10, 21),
        DateTime(2026, 10, 26),
        DateTime(2026, 11, 2)
      ]);
      final e = _eval([p], {'P1': pagos}, hoy);
      expect(_validar(e, 5000, tasa: 10).any((v) => v.tipo == TipoViolacion.tasaInferior), true);
      expect(_validar(e, 5000, tasa: 15).any((v) => v.tipo == TipoViolacion.tasaInferior), false);
      expect(_validar(e, 5000, tasa: 0).any((v) => v.tipo == TipoViolacion.tasaInferior), true);
    });

    test('cliente con tasa general: menos del 15% exige autorización, 15 o más no', () {
      final p = _prestamo(id: 'P1', inicio: DateTime(2026, 10, 5), tasa: 15);
      final e = _eval([p], {'P1': _pagosATiempo(p)}, hoy);
      expect(e.tasaMinimaPct, 15);
      final v = _validar(e, 12000, tasa: 12);
      expect(v.any((x) => x.tipo == TipoViolacion.tasaInferior), true);
      expect(v.firstWhere((x) => x.tipo == TipoViolacion.tasaInferior).mensaje, contains('autorización especial'));
      expect(_validar(e, 12000, tasa: 15).any((x) => x.tipo == TipoViolacion.tasaInferior), false);
      expect(_validar(e, 12000, tasa: 18).any((x) => x.tipo == TipoViolacion.tasaInferior), false);
    });

    test('cliente nuevo general también exige 15% por defecto', () {
      final e = _eval([], {}, hoy);
      expect(e.tasaMinimaPct, 15);
      expect(_validar(e, 1000, tasa: 10).any((x) => x.tipo == TipoViolacion.tasaInferior), true);
    });

    test('cliente con preferencial asignada: su tasa es el mínimo, subir está permitido', () {
      final e = _eval([], {}, hoy, asignada: 12);
      expect(e.tasaMinimaPct, 12);
      expect(_validar(e, 1000, tasa: 12).any((x) => x.tipo == TipoViolacion.tasaInferior), false);
      expect(_validar(e, 1000, tasa: 15).any((x) => x.tipo == TipoViolacion.tasaInferior), false);
      expect(_validar(e, 1000, tasa: 10).any((x) => x.tipo == TipoViolacion.tasaInferior), true);
    });

    test('administración fuerza tasa general aunque su último préstamo fuera a 12%', () {
      final p = _prestamo(id: 'P1', inicio: DateTime(2026, 10, 5), tasa: 12);
      final e = _eval([p], {'P1': _pagosATiempo(p)}, hoy, forzadaGeneral: true);
      expect(e.tasaTipo, 'general');
      expect(e.perdioTasaPreferencial, false);
      expect(e.tasaMinimaPct, 15);
      expect(e.motivoTasa.join(' '), contains('Administración le asignó la tasa general'));
    });

    test('la evaluación guardada se puede reconstruir para mostrarla al instante', () {
      final p = _prestamo(id: 'P1', inicio: DateTime(2026, 10, 5), tasa: 10);
      final e = _eval([p], {'P1': _pagosATiempo(p)}, hoy);
      final r = EvaluacionCredito.desdeAlmacenado(e.aMapaPersistido())!;
      expect(r.categoria, e.categoria);
      expect(r.tasaTipo, 'preferencial');
      expect(r.tasaVigentePct, 10);
      expect(r.totalMaximo, e.totalMaximo);
      expect(r.motivoCategoria, e.motivoCategoria);
      expect(EvaluacionCredito.desdeAlmacenado({'categoriaCredito': 'A'}), isNull);
    });

    test('administración asigna preferencial a un cliente nuevo', () {
      final e = _eval([], {}, hoy, asignada: 12);
      expect(e.tasaTipo, 'preferencial');
      expect(e.tasaVigentePct, 12);
      expect(e.tasaAsignadaPorAdmin, true);
      expect(e.motivoTasa.join(' '), contains('asignada por administración'));
    });

    test('tasa asignada >= 15 se ignora (no es preferencial)', () {
      final e = _eval([], {}, hoy, asignada: 15);
      expect(e.tasaTipo, 'general');
    });

    test('con tasa asignada y 2 atrasos en un préstamo posterior a la asignación -> la pierde', () {
      final p = _prestamo(id: 'P1', inicio: DateTime(2026, 10, 5), tasa: 15);
      final pagos = _pagosEnFechas(p, [
        DateTime(2026, 10, 14),
        DateTime(2026, 10, 21),
        DateTime(2026, 10, 26),
        DateTime(2026, 11, 2)
      ]);
      final e = _eval([p], {'P1': pagos}, hoy, asignada: 12, desde: DateTime(2026, 9, 1));
      expect(e.perdioTasaPreferencial, true);
      expect(e.tasaTipo, 'general');
    });

    test('si administración asigna DESPUÉS del préstamo con atrasos, la asignación manda', () {
      final p = _prestamo(id: 'P1', inicio: DateTime(2026, 10, 5), tasa: 15);
      final pagos = _pagosEnFechas(p, [
        DateTime(2026, 10, 14),
        DateTime(2026, 10, 21),
        DateTime(2026, 10, 26),
        DateTime(2026, 11, 2)
      ]);
      final e = _eval([p], {'P1': pagos}, hoy, asignada: 12, desde: DateTime(2026, 12, 1));
      expect(e.perdioTasaPreferencial, false);
      expect(e.tasaTipo, 'preferencial');
      expect(e.tasaVigentePct, 12);
    });
  });

  group('Regla 2: un solo préstamo activo', () {
    test('cliente con préstamo activo no puede crear otro, y el mensaje trae el detalle', () {
      final p = _prestamo(id: 'P1', inicio: DateTime(2027, 5, 20), saldado: false);
      final e = _eval([p], {'P1': const []}, hoy);
      final v = _validar(e, 1000);
      expect(v.first.tipo, TipoViolacion.prestamoActivo);
      expect(v.first.mensaje, contains('no se puede elegir porque ya cuenta con un préstamo activo'));
      expect(v.first.mensaje, contains('N° P1'));
      expect(v.first.mensaje, contains('L.12,000.00'));
      expect(v.first.mensaje, contains('20/05/2027'));
    });

    test('préstamo activo detectado por otra ficha con la misma identidad', () {
      final e = _eval([], {}, hoy);
      final v = _validar(e, 1000, externo: 'La identidad X ya tiene un préstamo activo en la ficha "Y".');
      expect(v.single.tipo, TipoViolacion.prestamoActivo);
      expect(v.single.mensaje, contains('ficha "Y"'));
    });

    test('cliente nuevo sin historial puede pedir cualquier total', () {
      final e = _eval([], {}, hoy);
      expect(_validar(e, 99999, tasa: 15), isEmpty);
    });
  });

  group('Regla 4: dejó vencer el crédito -> total a pagar 30% menor', () {
    test('ejemplo Fátima: total 12,000, pagó el 16 de noviembre -> máximo 8,400', () {
      final p = _prestamo(id: 'P1', inicio: DateTime(2026, 10, 5));
      final pagos = [
        _pago('P1', p.cuota, DateTime(2026, 10, 12), n: 1),
        _pago('P1', p.cuota, DateTime(2026, 10, 19), n: 2),
        _pago('P1', p.cuota, DateTime(2026, 10, 26), n: 3),
        _pago('P1', p.cuota, DateTime(2026, 11, 16), n: 4),
      ];
      final e = _eval([p], {'P1': pagos}, hoy);
      expect(e.ultimo!.vencimientoFinal, DateTime(2026, 11, 2));
      expect(e.ultimo!.vencidoTarde, true);
      expect(e.limitePorVencimiento, true);
      expect(e.totalMaximo, 8400);
      expect(e.incrementoElegible, false);
      expect(_validar(e, 12000).any((v) => v.tipo == TipoViolacion.montoExcedido), true);
      expect(_validar(e, 8400).any((v) => v.tipo == TipoViolacion.montoExcedido), false);
      final texto = e.motivoMonto.join(' ');
      expect(texto, contains('16/11/2026'));
      expect(texto, contains('02/11/2026'));
      expect(texto, contains('total a pagar'));
    });

    test('pagó justo el día del vencimiento -> no cuenta como vencido', () {
      final p = _prestamo(id: 'P1', inicio: DateTime(2026, 10, 5));
      final e = _eval([p], {'P1': _pagosATiempo(p)}, hoy);
      expect(e.ultimo!.vencidoTarde, false);
      expect(e.limitePorVencimiento, false);
    });
  });

  group('Regla 5: incremento del 20% tras 3 ciclos (sobre el total a pagar)', () {
    List<PrestamoModel> ciclos(int n, {double monto = 10000}) => [
          for (var i = 0; i < n; i++)
            _prestamo(id: 'P$i', inicio: DateTime(2026, 1, 5).add(Duration(days: 60 * i)), monto: monto),
        ];

    Map<String, List<PagoModel>> pagosOk(List<PrestamoModel> ps) =>
        {for (final p in ps) p.prestamoId: _pagosATiempo(p)};

    test('3 ciclos iguales y sin atrasos -> elegible, máximo +20% del total a pagar', () {
      final ps = ciclos(3);
      final e = _eval(ps, pagosOk(ps), hoy);
      expect(e.incrementoElegible, true);
      expect(e.totalMaximo, 14400);
      expect(_validar(e, 14400), isEmpty);
      expect(_validar(e, 14401).single.tipo, TipoViolacion.montoExcedido);
      expect(e.motivoIncremento.join(' '), contains('total a pagar'));
    });

    test('solo 2 ciclos -> no elegible y explica cuántos lleva', () {
      final ps = ciclos(2);
      final e = _eval(ps, pagosOk(ps), hoy);
      expect(e.incrementoElegible, false);
      expect(e.totalMaximo, 12000);
      expect(e.motivoIncremento.join(' '), contains('2 de 3'));
    });

    test('con atrasos en el último ciclo -> mensaje de que presentó atrasos', () {
      final ps = ciclos(3);
      final pagos = pagosOk(ps);
      final u = ps.last;
      pagos[u.prestamoId] = [
        _pago(u.prestamoId, u.cuota, u.fecha!.toDate().add(const Duration(days: 9)), n: 1),
        ..._pagosATiempo(u).skip(1),
      ];
      final e = _eval(ps, pagos, hoy);
      expect(e.incrementoElegible, false);
      expect(e.motivoIncremento.join(' '), contains('presentó atrasos'));
      final v = _validar(e, 14400);
      expect(v.single.mensaje, contains('No aplica a incremento'));
    });

    test('totales distintos entre ciclos reinician el conteo', () {
      final ps = [
        _prestamo(id: 'A', inicio: DateTime(2026, 1, 5), monto: 8000),
        _prestamo(id: 'B', inicio: DateTime(2026, 3, 5), monto: 10000),
        _prestamo(id: 'C', inicio: DateTime(2026, 5, 5), monto: 10000),
      ];
      final e = _eval(ps, pagosOk(ps), hoy);
      expect(e.incrementoElegible, false);
      expect(e.motivoIncremento.join(' '), contains('2 de 3'));
    });

    test('puede pedir menos que su último total', () {
      final ps = ciclos(1);
      final e = _eval(ps, pagosOk(ps), hoy);
      expect(_validar(e, 6000), isEmpty);
    });
  });

  group('Regla 6: Categoría C no aplica', () {
    test('categoría C bloquea nuevo préstamo con mensaje', () {
      final p = _prestamo(id: 'P1', inicio: DateTime(2026, 10, 5));
      final pagos = _pagosEnFechas(p, [
        DateTime(2026, 11, 10),
        DateTime(2026, 11, 10),
        DateTime(2026, 11, 10),
        DateTime(2026, 11, 10)
      ]);
      final e = _eval([p], {'P1': pagos}, hoy);
      expect(e.categoria, CategoriaCredito.c);
      final v = _validar(e, 1000);
      expect(v.any((x) => x.tipo == TipoViolacion.categoriaC), true);
      expect(v.firstWhere((x) => x.tipo == TipoViolacion.categoriaC).mensaje, contains('Categoría C'));
    });

    test('categoría B no bloquea, solo limita el total', () {
      final p = _prestamo(id: 'P1', inicio: DateTime(2026, 10, 5));
      final pagos = _pagosATiempo(p);
      pagos[0] = _pago('P1', p.cuota, DateTime(2026, 10, 15), n: 1);
      final e = _eval([p], {'P1': pagos}, hoy);
      expect(e.categoria, CategoriaCredito.b);
      expect(_validar(e, 12000), isEmpty);
    });
  });

  group('Pagos y datos raros', () {
    test('pago que paga varias cuotas de golpe cumple todas ese día', () {
      final p = _prestamo(id: 'P1', inicio: DateTime(2026, 10, 5));
      final e = _eval([p], {'P1': [_pago('P1', p.totalPagar, DateTime(2026, 10, 20))]}, hoy);
      final c = e.ultimo!.cuotas;
      expect(c[0].atrasada, true);
      expect(c[1].atrasada, true);
      expect(c[2].atrasada, false);
      expect(c[3].atrasada, false);
    });

    test('préstamo saldado sin pagos suficientes no deja cuotas colgadas', () {
      final p = _prestamo(id: 'P1', inicio: DateTime(2026, 10, 5));
      final e = _eval([p], {'P1': [_pago('P1', p.cuota * 3, DateTime(2026, 10, 26))]}, hoy);
      expect(e.ultimo!.cuotas.every((c) => c.pagada), true);
    });

    test('abono parcial a tiempo completado tarde cuenta como atraso', () {
      final p = _prestamo(id: 'P1', inicio: DateTime(2026, 10, 5));
      final pagos = [
        _pago('P1', p.cuota / 2, DateTime(2026, 10, 12), n: 1),
        _pago('P1', p.cuota / 2, DateTime(2026, 10, 15), n: 2),
        _pago('P1', p.cuota * 3, DateTime(2026, 10, 26), n: 3),
      ];
      final e = _eval([p], {'P1': pagos}, hoy);
      expect(e.ultimo!.cuotas[0].atrasada, true);
      expect(e.ultimo!.cuotas[0].diasAtraso, 3);
    });

    test('interés total fijo no tiene tasa propia: queda general', () {
      final p = _prestamo(id: 'P1', inicio: DateTime(2026, 10, 5), tasa: 0, usarInteresMensual: false);
      final e = _eval([p], {'P1': _pagosATiempo(p)}, hoy);
      expect(e.ultimo!.tasaPct, isNull);
      expect(e.tasaTipo, 'general');
    });

    test('toma como último el préstamo más reciente por fecha', () {
      final viejo = _prestamo(id: 'V', inicio: DateTime(2026, 1, 5), monto: 3000);
      final nuevo = _prestamo(id: 'N', inicio: DateTime(2026, 6, 5), monto: 9000);
      final e = _eval([nuevo, viejo], {'V': _pagosATiempo(viejo), 'N': _pagosATiempo(nuevo)}, hoy);
      expect(e.ultimo!.prestamo.prestamoId, 'N');
    });

    test('lo persistido siempre trae categoría y tipo de tasa', () {
      final e = _eval([], {}, hoy);
      final m = e.aMapaPersistido();
      expect(m['categoriaCredito'], 'A');
      expect(m['tasaTipo'], 'general');
      expect(m['prestamoActivoCredito'], false);
    });
  });
}
