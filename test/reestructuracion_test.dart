import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:capital_express/core/models/prestamo_model.dart';
import 'package:capital_express/core/utils/prestamo_estado_utils.dart';
import 'package:capital_express/core/utils/reglas_credito.dart';
import 'package:capital_express/features/prestamos/data/reestructuracion_service.dart';

void main() {
  final inicio = DateTime(2026, 9, 1);

  PrestamoModel original() => PrestamoModel(
        prestamoId: 'viejo',
        numeroPrestamo: 'PR-00001',
        clienteId: 'c1',
        monto: 10000,
        totalPagar: 12000,
        cuota: 3000,
        cuotas: 4,
        plazo: 'Semanal',
        interesMensual: 15,
        saldo: 0,
        estado: 'reestructurado',
        fecha: Timestamp.fromDate(inicio),
      );

  PrestamoModel nuevo() => PrestamoModel(
        prestamoId: 'nuevo',
        numeroPrestamo: 'PR-00002',
        clienteId: 'c1',
        monto: 9500,
        totalPagar: 11637.5,
        cuota: 1455,
        cuotas: 8,
        plazo: 'Semanal',
        interesMensual: 15,
        saldo: 11637.5,
        estado: 'activo',
        fecha: Timestamp.fromDate(DateTime(2026, 11, 1)),
        esReestructuracion: true,
        reestructuraDe: 'viejo',
      );

  test('la propuesta baja la cuota y sube el interes al dar mas cuotas', () {
    final corta = PropuestaReestructuracion(
        saldoActual: 9500, moraActual: 0, incluirMora: true, interesMensualPct: 15, cuotas: 4, plazo: 'Semanal',
        fechaInicio: DateTime(2026, 11, 1));
    final larga = PropuestaReestructuracion(
        saldoActual: 9500, moraActual: 0, incluirMora: true, interesMensualPct: 15, cuotas: 12, plazo: 'Semanal',
        fechaInicio: DateTime(2026, 11, 1));
    expect(larga.calculo.cuotaEstimada, lessThan(corta.calculo.cuotaEstimada));
    expect(larga.calculo.interesCalculado, greaterThan(corta.calculo.interesCalculado));
    expect(larga.base, 9500);
  });

  test('sin incluir la mora el capital baja en la mora', () {
    final p = PropuestaReestructuracion(
        saldoActual: 9500, moraActual: 500, incluirMora: false, interesMensualPct: 15, cuotas: 8, plazo: 'Semanal',
        fechaInicio: DateTime(2026, 11, 1));
    expect(p.base, 9000);
  });

  test('cliente reestructurado queda bloqueado para nuevos prestamos', () {
    final e = evaluarCredito(
      prestamos: [original()],
      pagosPorPrestamo: const {},
      hoy: DateTime(2026, 12, 1),
      clienteReestructurado: true,
      detalleReestructuracion: 'Préstamo N° PR-00001 reestructurado.',
    );
    expect(e.clienteReestructurado, isTrue);
    expect(e.incrementoElegible, isFalse);
    final v = validarNuevoPrestamo(evaluacion: e, totalAPagar: 1000, interesMensualPct: 15);
    expect(v.map((x) => x.tipo), contains(TipoViolacion.clienteReestructurado));
  });

  test('sin la marca no aparece el bloqueo de reestructuracion', () {
    final e = evaluarCredito(prestamos: [original()], pagosPorPrestamo: const {}, hoy: DateTime(2026, 12, 1));
    final v = validarNuevoPrestamo(evaluacion: e, totalAPagar: 1000, interesMensualPct: 15);
    expect(v.map((x) => x.tipo), isNot(contains(TipoViolacion.clienteReestructurado)));
  });

  test('el prestamo nuevo es el activo y el viejo no cuenta como activo', () {
    final e = evaluarCredito(
      prestamos: [original(), nuevo()],
      pagosPorPrestamo: const {},
      hoy: DateTime(2026, 11, 2),
      clienteReestructurado: true,
    );
    expect(e.tienePrestamoActivo, isTrue);
    expect(e.cicloActivo!.prestamo.prestamoId, 'nuevo');
    expect(estadoEfectivoPrestamo(original()), 'reestructurado');
  });

  test('desdeAlmacenado lee la marca del cliente', () {
    final e = EvaluacionCredito.desdeAlmacenado({
      'prestamoActivoCredito': false,
      'categoriaCredito': 'B',
      'reestructurado': true,
      'reestructuradoDetalle': 'x',
    })!;
    expect(e.clienteReestructurado, isTrue);
    expect(e.avisoReestructuracion, contains('No se le deben dar más préstamos'));
  });
}
