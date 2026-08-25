import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Envoltorio sobre local_auth -- solo Android (mismo alcance que el
/// resto de features moviles de esta app, ver InactividadGuard).
class BiometriaService {
  static final _auth = LocalAuthentication();

  static bool get _aplica => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Si el dispositivo tiene huella/Face ID configurado y disponible
  /// ahora mismo (no solo si el hardware existe).
  static Future<bool> disponible() async {
    if (!_aplica) return false;
    try {
      final soportado = await _auth.isDeviceSupported();
      final puedeChequear = await _auth.canCheckBiometrics;
      return soportado && puedeChequear;
    } catch (_) {
      return false;
    }
  }

  /// Muestra el prompt nativo de huella/Face ID. `true` solo si el
  /// usuario se autentico con exito.
  static Future<bool> autenticar({String razon = 'Confirmá tu identidad para continuar'}) async {
    if (!_aplica) return false;
    try {
      return await _auth.authenticate(
        localizedReason: razon,
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }
}
