import 'dart:convert';

import 'package:http/http.dart' as http;

/// Llama una Cloud Function callable como una peticion HTTP comun, NO
/// con `FirebaseFunctions.instance.httpsCallable` -- ese paquete
/// oficial de FlutterFire falla en Web (dart2js) con "Int64 accessor
/// not supported", un bug conocido de esa libreria al armar la llamada
/// (confirmado en produccion, ver Cobros). Pedirselo a la funcion como
/// una peticion HTTP cualquiera evita ese camino roto por completo --
/// funciona igual en Android/Web/Windows.
///
/// Todas las funciones de este proyecto viven en us-east1 (misma
/// region que la base de Firestore, ver functions/index.js).
Future<Map<String, dynamic>> llamarCloudFunction(
  String nombre,
  Map<String, dynamic> datos,
) async {
  final respuesta = await http
      .post(
        Uri.parse('https://us-east1-capitalexpressapp-c03c5.cloudfunctions.net/$nombre'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'data': datos}),
      )
      .timeout(const Duration(seconds: 15));

  final cuerpo = jsonDecode(respuesta.body) as Map<String, dynamic>;
  if (cuerpo['error'] != null) {
    throw Exception(cuerpo['error']);
  }
  return cuerpo['result'] as Map<String, dynamic>;
}
