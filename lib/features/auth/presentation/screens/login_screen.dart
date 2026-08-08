import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/responsive.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _codigoCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _verPassword = false;

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: esEscritorio(context) ? _layoutEscritorio(context) : _layoutMobile(context),
    );
  }

  Widget _layoutMobile(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/images/fondo_login.jpg', fit: BoxFit.cover),
        Container(color: Colors.black.withValues(alpha: 0.35)),
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
                  child: _contenidoFormulario(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _layoutEscritorio(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 6,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset('assets/images/fondo_login.jpg', fit: BoxFit.cover),
              Container(color: Colors.black.withValues(alpha: 0.25)),
              Positioned(
                left: 72,
                right: 72,
                bottom: 96,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield_outlined, color: Colors.white, size: 26),
                        const SizedBox(width: 10),
                        Text(
                          'CAPITAL EXPRESS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Tu socio financiero\nde confianza',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 460,
          color: CEColors.primary,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: _contenidoFormulario(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _contenidoFormulario() {
    final authState = ref.watch(authProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 100,
          height: 100,
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Image.asset('assets/images/logo_capital_express.png', fit: BoxFit.contain),
        ),
        const SizedBox(height: 24),
        const Text(
          'Iniciar Sesión',
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 28),
        _campoOscuro(
          label: 'Código de usuario',
          controller: _codigoCtrl,
          icono: Icons.person_outline,
          hint: 'Ingrese su código',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 18),
        _campoOscuro(
          label: 'Contraseña',
          controller: _passwordCtrl,
          icono: Icons.lock_outline,
          hint: 'Ingrese su contraseña',
          obscure: !_verPassword,
          onSubmit: (_) => _entrar(),
          suffix: IconButton(
            icon: Icon(
              _verPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: Colors.white70,
              size: 20,
            ),
            onPressed: () => setState(() => _verPassword = !_verPassword),
          ),
        ),
        if (authState.error != null) ...[
          const SizedBox(height: 14),
          Text(
            authState.error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFFF8A8A), fontSize: 13),
          ),
        ],
        const SizedBox(height: 26),
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
            onPressed: authState.cargando ? null : _entrar,
            child: authState.cargando
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: CEColors.primary),
                  )
                : const Text('Iniciar Sesión', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _campoOscuro({
    required String label,
    required TextEditingController controller,
    required IconData icono,
    required String hint,
    bool obscure = false,
    Widget? suffix,
    void Function(String)? onSubmit,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white),
          onSubmitted: onSubmit,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
            prefixIcon: Icon(icono, color: Colors.white70, size: 20),
            suffixIcon: suffix,
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
    );
  }

  void _entrar() {
    final codigo = _codigoCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (codigo.isEmpty || password.isEmpty) return;
    ref.read(authProvider.notifier).login(codigo, password);
  }
}
