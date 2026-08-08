import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/actualizacion_service.dart';

/// Ultima actualizacion detectada como disponible (por el chequeo
/// automatico al iniciar sesion o por "Buscar actualizaciones" en el
/// menu lateral). Sirve para que el menu se pinte distinto mientras
/// haya una actualizacion pendiente, incluso si el usuario cerro el
/// dialogo con "Despues" -- no se limpia sola: la unica forma de que
/// desaparezca es instalar la actualizacion (lo que cierra y reabre la
/// app) o volver a chequear y que ya no haya ninguna mas nueva.
class ActualizacionDisponibleNotifier extends Notifier<ActualizacionDisponible?> {
  @override
  ActualizacionDisponible? build() => null;

  void establecer(ActualizacionDisponible? actualizacion) {
    state = actualizacion;
  }
}

final actualizacionDisponibleProvider =
    NotifierProvider<ActualizacionDisponibleNotifier, ActualizacionDisponible?>(
  ActualizacionDisponibleNotifier.new,
);
