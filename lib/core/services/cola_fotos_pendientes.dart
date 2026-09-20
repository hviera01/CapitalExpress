import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'pendientes_sincronizar_service.dart';
import 'storage_service.dart';

/// Cola local de fotos de cliente pendientes de subir a Firebase
/// Storage -- a diferencia de Firestore (persistencia offline activada
/// globalmente en main.dart, ver PagoRepository.registrarPago), Storage
/// NO tiene una cola de reintento propia: si no hay señal, `putData`
/// simplemente falla ahi mismo. Por eso ClienteFormScreen ya no espera
/// a que las fotos terminen de subir para guardar el cliente y avisar
/// "listo" -- cada foto nueva se guarda primero en el disco del
/// telefono y se encola aca; si hay señal, sube casi al toque; si no,
/// queda pendiente y esta clase la reintenta sola (ver
/// InactividadGuard, que la engancha al volver a primer plano y a un
/// timer periodico).
class ColaFotosPendientes {
  ColaFotosPendientes._();

  static const _clavePrefs = 'cola_fotos_pendientes';
  static const _uuid = Uuid();
  static final _enProceso = <String>{};

  static final ValueNotifier<int> cantidadPendiente = ValueNotifier<int>(0);

  static Future<Directory> _carpeta() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/fotos_pendientes');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<List<Map<String, dynamic>>> _leerCola() async {
    final prefs = await SharedPreferences.getInstance();
    final texto = prefs.getString(_clavePrefs);
    if (texto == null || texto.isEmpty) return [];
    return (jsonDecode(texto) as List).cast<Map<String, dynamic>>();
  }

  static Future<void> _guardarCola(List<Map<String, dynamic>> cola) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clavePrefs, jsonEncode(cola));
    cantidadPendiente.value = cola.length;
  }

  /// Guarda [bytes] en el disco del telefono y la agrega a la cola --
  /// devuelve enseguida (no espera a que suba), e intenta subirla de
  /// una en segundo plano.
  static Future<void> encolar({
    required String clienteId,
    required String campo,
    required Uint8List bytes,
  }) async {
    final dir = await _carpeta();
    final id = _uuid.v4();
    final archivo = File('${dir.path}/$id.jpg');
    await archivo.writeAsBytes(bytes);

    final cola = await _leerCola();
    cola.add({'id': id, 'clienteId': clienteId, 'campo': campo, 'ruta': archivo.path});
    await _guardarCola(cola);

    _intentarSubir(cola.last);
  }

  /// Reintenta TODAS las fotos pendientes que no esten ya en vuelo --
  /// se llama al volver a primer plano y desde un timer periodico
  /// mientras haya pendientes (ver InactividadGuard).
  static Future<void> reintentarTodos() async {
    final cola = await _leerCola();
    for (final entrada in cola) {
      _intentarSubir(entrada);
    }
  }

  static Future<void> _intentarSubir(Map<String, dynamic> entrada) async {
    final id = entrada['id'] as String;
    if (_enProceso.contains(id)) return;
    _enProceso.add(id);

    try {
      final archivo = File(entrada['ruta'] as String);
      if (!await archivo.exists()) {
        await _quitarDeCola(id); // el archivo local ya no esta -- no hay nada que reintentar
        return;
      }
      final bytes = await archivo.readAsBytes();
      final url = await StorageService()
          .subirFoto(bytes: bytes, carpeta: 'clientes')
          .timeout(const Duration(seconds: 20));

      PendientesSincronizarService.rastrear(
        FirebaseFirestore.instance
            .collection('clientes')
            .doc(entrada['clienteId'] as String)
            .update({entrada['campo'] as String: url}),
        descripcion: 'Foto de cliente (${entrada['campo']})',
      );

      await _quitarDeCola(id);
      await archivo.delete().catchError((_) => archivo);
    } catch (_) {
      // Sin señal (o Storage no contesto a tiempo): se deja en la cola
      // para el proximo intento -- NO se descarta, es justamente el
      // caso que esta cola existe para cubrir.
    } finally {
      _enProceso.remove(id);
    }
  }

  static Future<void> _quitarDeCola(String id) async {
    final cola = await _leerCola();
    cola.removeWhere((e) => e['id'] == id);
    await _guardarCola(cola);
  }

  /// Se llama una vez al arrancar la app para que el contador del
  /// badge ya refleje lo que haya quedado pendiente de una sesion
  /// anterior (ej. se cerro la app con el celular sin señal).
  static Future<void> inicializar() async {
    final cola = await _leerCola();
    cantidadPendiente.value = cola.length;
    reintentarTodos();
  }
}
