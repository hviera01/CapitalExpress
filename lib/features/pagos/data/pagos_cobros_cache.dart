import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class EntradaPagosCobros {
  final String firma;
  final int guardadoMs;
  final List<Map<String, dynamic>> pagos;

  const EntradaPagosCobros({required this.firma, required this.guardadoMs, required this.pagos});

  Map<String, dynamic> toJson() => {'f': firma, 't': guardadoMs, 'p': pagos};

  static EntradaPagosCobros? desdeJson(dynamic j) {
    if (j is! Map) return null;
    final firma = j['f'];
    final t = j['t'];
    final p = j['p'];
    if (firma is! String || t is! int || p is! List) return null;
    return EntradaPagosCobros(
      firma: firma,
      guardadoMs: t,
      pagos: [for (final x in p) if (x is Map) Map<String, dynamic>.from(x)],
    );
  }
}

class PagosCobrosCache {
  static const _clave = 'cobros_pagos_cache_v1';
  static const vigencia = Duration(hours: 6);

  static Future<Map<String, EntradaPagosCobros>> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final crudo = prefs.getString(_clave);
      if (crudo == null || crudo.isEmpty) return {};
      final json = jsonDecode(crudo);
      if (json is! Map) return {};
      final resultado = <String, EntradaPagosCobros>{};
      json.forEach((k, v) {
        final e = EntradaPagosCobros.desdeJson(v);
        if (e != null && k is String) resultado[k] = e;
      });
      return resultado;
    } catch (_) {
      return {};
    }
  }

  static Map<String, String> firmasVigentes(Map<String, EntradaPagosCobros> cache) {
    final limite = DateTime.now().subtract(vigencia).millisecondsSinceEpoch;
    return {
      for (final e in cache.entries)
        if (e.value.guardadoMs >= limite) e.key: e.value.firma,
    };
  }

  static Future<void> guardar(Map<String, EntradaPagosCobros> cache) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_clave, jsonEncode({for (final e in cache.entries) e.key: e.value.toJson()}));
    } catch (_) {}
  }

  static Future<void> limpiar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_clave);
    } catch (_) {}
  }
}
