import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/prestamo_model.dart';

/// Guarda la ultima busqueda de Ver Prestamos (texto, filtros y
/// resultados) para que al salir de la pantalla y volver a entrar NO
/// se pierda lo que se estaba buscando -- ver ClientesBusquedaCache
/// (mismo patron).
class PrestamosBusquedaCache {
  String texto = '';
  String filtroEstado = 'Todos';
  bool verEliminados = false;
  bool seBusco = false;
  List<PrestamoModel> resultados = [];

  // Estadisticas del encabezado (Total/Activos/Saldados) -- se
  // guardan tambien, para que al volver a la pantalla se vean de una
  // (sin el parpadeo de "..." mientras se vuelven a pedir) y la
  // actualizacion real pase calladita atras.
  bool tieneStats = false;
  int total = 0;
  int activos = 0;
  int saldados = 0;
}

final prestamosBusquedaCacheProvider =
    Provider<PrestamosBusquedaCache>((ref) => PrestamosBusquedaCache());
