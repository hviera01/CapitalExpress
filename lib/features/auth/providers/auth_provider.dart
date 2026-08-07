import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/usuario_model.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

class AuthState {
  final UsuarioModel? usuario;
  final bool cargando;
  final String? error;

  const AuthState({this.usuario, this.cargando = false, this.error});

  bool get autenticado => usuario != null;

  AuthState copyWith({
    UsuarioModel? usuario,
    bool? cargando,
    String? error,
    bool limpiarError = false,
  }) {
    return AuthState(
      usuario: usuario ?? this.usuario,
      cargando: cargando ?? this.cargando,
      error: limpiarError ? null : (error ?? this.error),
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
    final usuario = await ref.read(authRepositoryProvider).sesionGuardada();
    state = AuthState(usuario: usuario, cargando: false);
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
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
