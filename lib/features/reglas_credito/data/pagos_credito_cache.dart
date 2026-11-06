import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/pago_model.dart';
import '../../../core/models/prestamo_model.dart';

String firmaPrestamoCredito(PrestamoModel p) {
  int c(double v) => (v * 100).round();
  final f = p.fechaUltimaActualizacion?.millisecondsSinceEpoch ?? 0;
  return '${c(p.montoPagado)}|${c(p.saldo)}|${c(p.mora)}|${p.estado}|$f';
}

class EntradaPagosCredito {
  final String firma;
  final int guardadoMs;
  final List<PagoModel> pagos;

  const EntradaPagosCredito({required this.firma, required this.guardadoMs, required this.pagos});

  Map<String, dynamic> toJson() => {
        'f': firma,
        't': guardadoMs,
        'p': [
          for (final p in pagos) [p.fechaPago?.millisecondsSinceEpoch ?? 0, p.monto, p.mora],
        ],
      };

  static EntradaPagosCredito? desdeJson(String prestamoId, dynamic j) {
    if (j is! Map) return null;
    final firma = j['f'];
    final t = j['t'];
    final p = j['p'];
    if (firma is! String || t is! int || p is! List) return null;
    final pagos = <PagoModel>[];
    for (final x in p) {
      if (x is! List || x.length < 3) return null;
      final ms = (x[0] as num).toInt();
      pagos.add(PagoModel(
        docId: '',
        prestamoId: prestamoId,
        monto: (x[1] as num).toDouble(),
        mora: (x[2] as num).toDouble(),
        fechaPago: ms == 0 ? null : Timestamp.fromMillisecondsSinceEpoch(ms),
      ));
    }
    return EntradaPagosCredito(firma: firma, guardadoMs: t, pagos: pagos);
  }
}

class PagosCreditoCache {
  static const _clave = 'credito_pagos_cache_v1';
  static const vigencia = Duration(days: 14);

  static Future<Map<String, EntradaPagosCredito>> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final crudo = prefs.getString(_clave);
      if (crudo == null || crudo.isEmpty) return {};
      final json = jsonDecode(crudo);
      if (json is! Map) return {};
      final resultado = <String, EntradaPagosCredito>{};
      json.forEach((k, v) {
        if (k is! String) return;
        final e = EntradaPagosCredito.desdeJson(k, v);
        if (e != null) resultado[k] = e;
      });
      return resultado;
    } catch (_) {
      return {};
    }
  }

  static bool esVigente(EntradaPagosCredito e) =>
      e.guardadoMs >= DateTime.now().subtract(vigencia).millisecondsSinceEpoch;

  static Future<void> guardar(Map<String, EntradaPagosCredito> cache) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_clave, jsonEncode({for (final e in cache.entries) e.key: e.value.toJson()}));
    } catch (_) {}
  }
}
