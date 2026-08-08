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

  // Estadisticas del encabezado (Total/Activos/Pagos Tarde/Pendiente) y
  // nombres de cobradores -- se guardan tambien, para que al volver a
  // la pantalla se vean de una (sin el parpadeo de "..." mientras se
  // vuelven a pedir) y la actualizacion real pase calladita atras.
  bool tieneStats = false;
  int total = 0;
  int activos = 0;
  int pagosTarde = 0;
  double pendiente = 0;
  Map<String, String> nombresCobradores = {};
}

final clientesBusquedaCacheProvider = Provider<ClientesBusquedaCache>((ref) => ClientesBusquedaCache());
