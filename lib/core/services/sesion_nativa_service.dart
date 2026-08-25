import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Puente con MainActivity.kt: consulta si la app fue quitada de la
/// multitarea (swipe en "recientes") desde la ULTIMA vez que se abrio
/// -- ver onTaskRemoved del lado nativo. Solo aplica en Android; en
/// Web/Windows este canal no existe y siempre devuelve false (esas
/// plataformas no tienen "recientes" para quitar la app de esa forma).
class SesionNativaService {
  static const _canal = MethodChannel('capitalexpress/sesion');

  static Future<bool> consumirCierreForzado() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _canal.invokeMethod<bool>('consumirCierreForzado') ?? false;
    } catch (_) {
      return false;
    }
  }
}
