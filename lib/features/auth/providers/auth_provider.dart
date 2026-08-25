import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/usuario_model.dart';
import '../../../core/services/sesion_nativa_service.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

class AuthState {
  final UsuarioModel? usuario;
  final bool cargando;
  final String? error;
  final bool bloqueado;

  const AuthState({this.usuario, this.cargando = false, this.error, this.bloqueado = false});

  bool get autenticado => usuario != null;

  AuthState copyWith({
    UsuarioModel? usuario,
    bool? cargando,
    String? error,
    bool limpiarError = false,
    bool? bloqueado,
  }) {
    return AuthState(
      usuario: usuario ?? this.usuario,
      cargando: cargando ?? this.cargando,
      error: limpiarError ? null : (error ?? this.error),
      bloqueado: bloqueado ?? this.bloqueado,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    _restaurarSesion();
    return const AuthState(cargando: true);
  }

  Future<void> _restaurarSesion() async {
    final repo = ref.read(authRepositoryProvider);

    // Si la app fue quitada de la multitarea desde la ultima vez que
    // se abrio, la sesion se cierra de una -- ver
    // MainActivity.onTaskRemoved. Cuando SI se detecta (no siempre:
    // Android puede haber matado el Service antes por ahorro de
    // bateria, ver nota abajo) es el caso mas fuerte: cierre completo,
    // pide el codigo de nuevo.
    final cierreForzado = await SesionNativaService.consumirCierreForzado();
    if (cierreForzado) {
      await repo.cerrarSesion();
      state = const AuthState(cargando: false);
      return;
    }

    final usuario = await repo.sesionGuardada();
    if (usuario == null) {
      state = const AuthState(cargando: false);
      return;
    }

    // CUALQUIER arranque en frio de la app (build() de este notifier
    // solo corre una vez por proceso) pide confirmar identidad de
    // nuevo, sin importar cuanto tiempo paso -- no existe una forma
    // confiable en Android de distinguir "la cerraron a proposito" de
    // "el sistema mato el proceso por memoria/bateria" (que pasa MUY
    // seguido, sobre todo en Samsung/Xiaomi con ahorro de bateria
    // agresivo -- confirmado: el Service de arriba a veces no llega a
    // avisar). Por eso ya no se restaura la sesion de un tiron nunca:
    // siempre arranca bloqueada, se desbloquea con huella/Face ID o
    // contrasena (sin perder de vista quien era). El limite de 1h en
    // segundo plano (revisarLimiteBackground) es aparte, para cuando
    // el proceso siguio vivo todo el tiempo sin llegar a este metodo.
    await repo.bloquear();
    state = AuthState(usuario: usuario, cargando: false, bloqueado: true);
  }

  Future<void> login(String codigo, String password) async {
    state = state.copyWith(cargando: true, limpiarError: true);
    try {
      final usuario = await ref.read(authRepositoryProvider).login(codigo, password);
      state = AuthState(usuario: usuario, cargando: false);
    } on AuthException catch (e) {
      state = AuthState(usuario: null, cargando: false, error: e.mensaje);
    } catch (_) {
      state = const AuthState(
        usuario: null,
        cargando: false,
        error: 'No se pudo conectar. Revisa tu conexion e intenta de nuevo.',
      );
    }
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).cerrarSesion();
    state = const AuthState();
  }

  /// App recien mandada a segundo plano (no quitada de la multitarea,
  /// solo minimizada) -- arranca a contar el limite de 1h.
  Future<void> registrarBackground() async {
    if (!state.autenticado) return;
    await ref.read(authRepositoryProvider).marcarBackground();
  }

  /// Al volver a primer plano: si ya paso el limite desde que se
  /// registro el ultimo background, bloquea la sesion (pide
  /// desbloquear, sin cerrarla del todo).
  Future<void> revisarLimiteBackground() async {
    if (!state.autenticado || state.bloqueado) return;
    final repo = ref.read(authRepositoryProvider);
    if (await repo.backgroundExcedioLimite()) {
      await repo.bloquear();
      state = state.copyWith(bloqueado: true);
    }
  }

  /// Desbloqueo con huella/Face ID -- ya se confirmo la identidad del
  /// lado del sistema operativo, no hace falta pedir contrasena.
  Future<void> desbloquearConBiometria() async {
    await ref.read(authRepositoryProvider).desbloquear();
    state = state.copyWith(bloqueado: false);
  }

  /// Desbloqueo con contrasena (respaldo cuando no hay huella/Face ID
  /// configurado en el telefono). No pide el codigo de nuevo: ya se
  /// sabe quien es por la sesion guardada.
  Future<bool> desbloquearConPassword(String password) async {
    final uid = state.usuario?.uid;
    if (uid == null) return false;
    final ok = await ref.read(authRepositoryProvider).verificarPassword(uid, password);
    if (ok) {
      await ref.read(authRepositoryProvider).desbloquear();
      state = state.copyWith(bloqueado: false);
    }
    return ok;
  }

  Future<bool> biometricoActivo() => ref.read(authRepositoryProvider).biometricoActivo();

  Future<void> setBiometricoActivo(bool activo) =>
      ref.read(authRepositoryProvider).setBiometricoActivo(activo);
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
