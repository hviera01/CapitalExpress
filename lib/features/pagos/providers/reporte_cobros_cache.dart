import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/pago_model.dart';
import '../../../core/models/usuario_simple.dart';

/// Guarda el ultimo Reporte de Cobros (rango de fechas, filtro de
/// cobrador y resultados) para que al salir de la pantalla y volver a
/// entrar se vea de una, con el mismo filtro que se habia dejado --
/// mismo patron que ClientesBusquedaCache.
class ReporteCobrosCache {
  bool tieneDatos = false;
  DateTime? fechaInicio;
  DateTime? fechaFin;
  String? filtroCobradorUid;
  List<PagoModel> pagos = [];
  List<UsuarioSimple> cobradores = [];
}

final reporteCobrosCacheProvider = Provider<ReporteCobrosCache>((ref) => ReporteCobrosCache());
