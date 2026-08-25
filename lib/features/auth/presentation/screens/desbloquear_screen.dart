import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/biometria_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

/// Se muestra cuando la sesion sigue "viva" (no se cerro del todo)
/// pero quedo bloqueada -- ver AuthState.bloqueado: la app estuvo mas
/// de 1h en segundo plano sin quitarse de la multitarea. A diferencia
/// de LoginScreen, ya se sabe quien es (no pide el codigo de nuevo),
/// solo confirma identidad con huella/Face ID o contrasena.
class DesbloquearScreen extends ConsumerStatefulWidget {
  const DesbloquearScreen({super.key});

  @override
  ConsumerState<DesbloquearScreen> createState() => _DesbloquearScreenState();
}

class _DesbloquearScreenState extends ConsumerState<DesbloquearScreen> {
  final _passwordCtrl = TextEditingController();
  bool _verPassword = false;
  bool _biometriaDisponible = false;
  bool _intentandoBiometria = false;
  bool _mostrarPassword = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepararBiometria());
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _prepararBiometria() async {
    final activo = await ref.read(authProvider.notifier).biometricoActivo();
    final disponible = activo && await BiometriaService.disponible();
    if (!mounted) return;
    setState(() => _biometriaDisponible = disponible);
    if (disponible) _intentarBiometria();
  }

  Future<void> _intentarBiometria() async {
    setState(() {
      _intentandoBiometria = true;
      _error = null;
    });
    final ok = await BiometriaService.autenticar(razon: 'Confirmá tu identidad para continuar');
    if (!mounted) return;
    setState(() => _intentandoBiometria = false);
    if (ok) {
      await ref.read(authProvider.notifier).desbloquearConBiometria();
    }
  }

  Future<void> _confirmarPassword() async {
    final password = _passwordCtrl.text;
    if (password.isEmpty) return;
    setState(() => _error = null);
    final ok = await ref.read(authProvider.notifier).desbloquearConPassword(password);
    if (!mounted) return;
    if (ok) {
      TextInput.finishAutofillContext();
    } else {
      setState(() => _error = 'Contraseña incorrecta');
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(authProvider).usuario;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/fondo_login.jpg', fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: 0.5)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.lock_outline, color: Colors.white, size: 38),
                        ),
                        const SizedBox(height: 20),
                        const Text('Sesión bloqueada',
                            style: TextStyle(
                                color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(
                          usuario?.nombre ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 28),
                        if (_biometriaDisponible && !_mostrarPassword) ...[
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD8E2FF),
                                foregroundColor: CEColors.primary,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: _intentandoBiometria
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: CEColors.primary),
                                    )
                                  : const Icon(Icons.fingerprint),
                              onPressed: _intentandoBiometria ? null : _intentarBiometria,
                              label: const Text('Usar huella / Face ID',
                                  style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextButton(
                            onPressed: () => setState(() => _mostrarPassword = true),
                            child: const Text('Usar contraseña en su lugar',
                                style: TextStyle(color: Colors.white70)),
                          ),
                        ] else ...[
                          _campoPassword(),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(_error!,
                                style: const TextStyle(color: Color(0xFFFF8A8A), fontSize: 13)),
                          ],
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD8E2FF),
                                foregroundColor: CEColors.primary,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: _confirmarPassword,
                              child: const Text('Continuar',
                                  style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                          if (_biometriaDisponible) ...[
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: () => setState(() => _mostrarPassword = false),
                              child: const Text('Usar huella / Face ID en su lugar',
                                  style: TextStyle(color: Colors.white70)),
                            ),
                          ],
                        ],
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => ref.read(authProvider.notifier).logout(),
                          child: const Text('Cerrar sesión',
                              style: TextStyle(color: Colors.white38, fontSize: 12.5)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _campoPassword() {
    return AutofillGroup(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Contraseña',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordCtrl,
          obscureText: !_verPassword,
          autofocus: !_biometriaDisponible,
          autofillHints: const [AutofillHints.password],
          style: const TextStyle(color: Colors.white),
          onSubmitted: (_) => _confirmarPassword(),
          decoration: InputDecoration(
            hintText: 'Ingresá tu contraseña',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
            prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _verPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: Colors.white70,
                size: 20,
              ),
              onPressed: () => setState(() => _verPassword = !_verPassword),
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.08),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: CEColors.accent, width: 1.5),
            ),
          ),
        ),
      ],
      ),
    );
  }
}
