import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/screens/cobros_screen.dart';

/// Guarda la ultima lista de Cobros calculada (cuotas vencidas y
/// proximas) para que al salir de la pantalla y volver a entrar se
/// vea de una -- ese calculo hace varias consultas a Firestore
/// (prestamos + fechas de ultimo pago por lotes) y se sentia pesado
/// repetirlo cada vez. Mismo patron que ClientesBusquedaCache.
class CobrosCache {
  bool tieneDatos = false;
  List<NotifCobro> notificaciones = [];
}

final cobrosCacheProvider = Provider<CobrosCache>((ref) => CobrosCache());
