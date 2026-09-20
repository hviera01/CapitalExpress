import 'package:flutter/foundation.dart';

/// Rastrea escrituras "optimistas" (registrar pago, subir foto de
/// cliente) que ya se dispararon y se dieron por buenas en pantalla
/// SIN esperar la confirmacion del servidor -- ver comentario en
/// PagoRepository.registrarPago y ColaFotosPendientes. Un simple
/// ValueNotifier alcanza (cualquier widget lo puede escuchar con
/// ValueListenableBuilder), no hace falta que sea un provider de
/// Riverpod para esto.
class PendientesSincronizarService {
  PendientesSincronizarService._();

  /// Cuantas escrituras siguen "en vuelo" (disparadas, sin confirmar
  /// todavia -- si no hay señal, Firestore las deja pendientes hasta
  /// que vuelva la conexion, sin tirar error).
  static final ValueNotifier<int> enVuelo = ValueNotifier<int>(0);

  /// Escrituras que fallaron de verdad (no por falta de señal --
  /// Firestore no tira error solo por estar offline, lo deja pendiente
  /// hasta reconectar -- sino por un problema real: el doc ya no
  /// existe, datos invalidos, etc.). Se acumulan aca para que quede un
  /// aviso visible hasta que alguien lo revise.
  static final ValueNotifier<List<String>> errores = ValueNotifier<List<String>>([]);

  /// Cuenta total para el badge: en vuelo + con error sin revisar. Una
  /// sola instancia compartida (no una nueva por cada `ref.watch`/
  /// `ValueListenableBuilder`, que dejaria listeners acumulandose sin
  /// nunca soltarse).
  static final ValueListenable<int> total = _TotalNotifier();

  /// Dispara [escritura] SIN esperarla (no bloquea al que llama) y
  /// sube/baja [enVuelo] mientras esta pendiente. Si termina fallando
  /// de verdad, agrega [descripcion] a [errores] en vez de perderla.
  static void rastrear(Future<void> escritura, {required String descripcion}) {
    enVuelo.value++;
    escritura.then((_) {
      enVuelo.value--;
    }, onError: (Object e, StackTrace st) {
      enVuelo.value--;
      errores.value = [...errores.value, '$descripcion: $e'];
    });
  }

  /// Se llama cuando un admin ya revisó y descartó los errores
  /// acumulados (no hay forma automática de saber que "se solucionó").
  static void limpiarErrores() => errores.value = [];
}

class _TotalNotifier extends ValueNotifier<int> {
  _TotalNotifier() : super(0) {
    void recalcular() =>
        value = PendientesSincronizarService.enVuelo.value + PendientesSincronizarService.errores.value.length;
    PendientesSincronizarService.enVuelo.addListener(recalcular);
    PendientesSincronizarService.errores.addListener(recalcular);
    recalcular();
  }
}
