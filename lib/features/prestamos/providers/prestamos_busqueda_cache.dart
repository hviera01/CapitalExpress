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
}

final prestamosBusquedaCacheProvider =
    Provider<PrestamosBusquedaCache>((ref) => PrestamosBusquedaCache());
