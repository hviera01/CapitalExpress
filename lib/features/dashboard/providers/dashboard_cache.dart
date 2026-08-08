import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Guarda el ultimo Dashboard calculado (todas las tarjetas + el
/// filtro de fechas usado) para que al salir de la pantalla y volver
/// a entrar se vea de una -- mismo patron que ClientesBusquedaCache.
class DashboardCache {
  bool tieneDatos = false;
  DateTime? fechaInicio;
  DateTime? fechaFin;

  int totalClientes = 0;
  double totalPrestado = 0;
  double totalInteres = 0;
  double totalPendiente = 0;
  int totalCobros = 0;
  double totalPagado = 0;
  double totalMoras = 0;
  int cantidadMoras = 0;
  Map<String, double> porCobrador = {};
  int prestamosActivos = 0;
  int prestamosMora = 0;
  int prestamosSaldados = 0;
}

final dashboardCacheProvider = Provider<DashboardCache>((ref) => DashboardCache());
