import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:capital_express/core/models/pago_model.dart';
import 'package:capital_express/core/models/prestamo_model.dart';
import 'package:capital_express/core/utils/cuotas_calculos.dart';
import 'package:capital_express/core/utils/reglas_credito.dart';
import 'package:capital_express/features/pagos/data/pagos_cobros_cache.dart';
import 'package:capital_express/features/reglas_credito/data/pagos_credito_cache.dart';

PrestamoModel _prestamo(String id, DateTime inicio, {bool saldado = true, double pagado = 0}) {
  const monto = 10000.0;
  const total = monto * 1.2;
  return PrestamoModel(
    prestamoId: id,
    numeroPrestamo: id,
    clienteId: 'c1',
    cliente: 'CLIENTE',
    monto: monto,
    totalPagar: total,
    cuota: 3000,
    cuotas: 4,
    plazo: 'Semanal',
    interesMensual: 15,
    usarInteresMensual: true,
    saldo: saldado ? 0 : total - pagado,
    montoPagado: pagado,
    estado: saldado ? 'saldado' : 'activo',
    fecha: Timestamp.fromDate(inicio),
  );
}

PagoModel _pago(String prestamoId, double monto, DateTime fecha, int n) =>
    PagoModel(docId: 'p$n', prestamoId: prestamoId, monto: monto, fechaPago: Timestamp.fromDate(fecha));

void main() {
  group('cache de pagos para credito', () {
    test('evaluar con pagos recuperados de la cache da el mismo resultado', () {
      final hoy = DateTime(2026, 11, 6);
      final p1 = _prestamo('a', DateTime(2026, 1, 5));
      final p2 = _prestamo('b', DateTime(2026, 6, 1), saldado: false, pagado: 3000);
      final pagos = {
        'a': [
          _pago('a', 3000, DateTime(2026, 1, 12), 1),
          _pago('a', 3000, DateTime(2026, 1, 26), 2),
          _pago('a', 6000, DateTime(2026, 3, 2), 3),
        ],
        'b': [_pago('b', 3000, DateTime(2026, 6, 20), 4)],
      };

      final recuperados = <String, List<PagoModel>>{};
      for (final e in pagos.entries) {
        final entrada = EntradaPagosCredito(firma: 'x', guardadoMs: 1, pagos: e.value);
        final json = jsonDecode(jsonEncode(entrada.toJson()));
        recuperados[e.key] = EntradaPagosCredito.desdeJson(e.key, json)!.pagos;
      }

      final original = evaluarCredito(prestamos: [p1, p2], pagosPorPrestamo: pagos, hoy: hoy);
      final conCache = evaluarCredito(prestamos: [p1, p2], pagosPorPrestamo: recuperados, hoy: hoy);

      expect(conCache.categoria, original.categoria);
      expect(conCache.tasaTipo, original.tasaTipo);
      expect(conCache.motivoCategoria, original.motivoCategoria);
      expect(conCache.tienePrestamoActivo, original.tienePrestamoActivo);
      expect(conCache.ciclos.length, original.ciclos.length);
      for (var i = 0; i < original.ciclos.length; i++) {
        expect(conCache.ciclos[i].cuotasAtrasadas, original.ciclos[i].cuotasAtrasadas);
        expect(conCache.ciclos[i].maxSemanasAtraso, original.ciclos[i].maxSemanasAtraso);
      }
    });

    test('la firma cambia cuando entra o se borra un pago', () {
      final antes = _prestamo('a', DateTime(2026, 1, 5), saldado: false, pagado: 3000);
      final despues = _prestamo('a', DateTime(2026, 1, 5), saldado: false, pagado: 6000);
      expect(firmaPrestamoCredito(antes), isNot(firmaPrestamoCredito(despues)));
      expect(firmaPrestamoCredito(antes), firmaPrestamoCredito(_prestamo('a', DateTime(2026, 1, 5), saldado: false, pagado: 3000)));
    });
  });

  group('cache de pagos para cobros', () {
    final crudo = <String, dynamic>{
      'id': 'p1',
      'prestamoId': 'a',
      'clienteId': 'c1',
      'numeroPrestamo': '12',
      'monto': 3000,
      'mora': 0,
      'fechaPago': DateTime(2026, 10, 1).millisecondsSinceEpoch,
      'cuotasCubiertas': [
        {'numeroCuota': 1, 'montoAplicado': 3000, 'completada': true},
      ],
      'totalCuotasCompletas': 1,
    };

    test('ida y vuelta por JSON conserva el pago y la tabla de cuotas', () {
      final entrada = EntradaPagosCobros(firma: 'f', guardadoMs: 5, pagos: [crudo]);
      final vuelta = EntradaPagosCobros.desdeJson(jsonDecode(jsonEncode(entrada.toJson())))!;
      expect(vuelta.firma, 'f');
      final pago = PagoModel.fromMap('p1', vuelta.pagos.single);
      expect(pago.monto, 3000);
      expect(pago.fechaPago!.toDate(), DateTime(2026, 10, 1));

      final prestamo = _prestamo('a', DateTime(2026, 9, 24), saldado: false, pagado: 3000);
      final tabla = construirTablaCuotas(prestamo, [pago]);
      expect(tabla.first.estado, EstadoCuota.pagada);
      expect(tabla[1].estado, EstadoCuota.pendiente);
    });

    test('un pago sin los campos pesados (firma, lugar) se interpreta igual', () {
      final pago = PagoModel.fromMap('p1', crudo);
      expect(pago.firma, '');
      expect(pago.cuotasCubiertas.single.numeroCuota, 1);
    });
  });
}
