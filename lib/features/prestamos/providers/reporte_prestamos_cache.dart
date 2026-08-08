import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/prestamo_model.dart';

/// Guarda la ultima lista de Reporte de Prestamos para que al salir de
/// la pantalla y volver a entrar se vea de una -- mismo patron que
/// ClientesBusquedaCache.
class ReportePrestamosCache {
  bool tieneDatos = false;
  List<PrestamoModel> prestamos = [];
}

final reportePrestamosCacheProvider =
    Provider<ReportePrestamosCache>((ref) => ReportePrestamosCache());
