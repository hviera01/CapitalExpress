import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/cliente_model.dart';

/// Guarda la ultima busqueda de Ver Clientes (texto, filtro y
/// resultados) para que al salir de la pantalla y volver a entrar NO
/// se pierda lo que se estaba buscando -- antes cada vez que se
/// volvia, la pantalla arrancaba en blanco y habia que repetir la
/// busqueda a mano. Es un simple objeto mutable (no un Notifier con
/// estado inmutable) porque solo sirve de "cajita" donde guardar el
/// ultimo estado; no dispara reconstrucciones reactivas en otro lado.
class ClientesBusquedaCache {
  String texto = '';
  String filtroEstado = 'Todos';
  bool seBusco = false;
  List<ClienteModel> resultados = [];
  Map<String, bool> tienePrestamoReal = {};
}

final clientesBusquedaCacheProvider = Provider<ClientesBusquedaCache>((ref) => ClientesBusquedaCache());
