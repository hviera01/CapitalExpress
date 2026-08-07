import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_provider.dart';

const _tiempoInactividad = Duration(hours: 1);

/// Envuelve toda la app (por encima del Navigator, en el `builder` de
/// MaterialApp.router): si pasa una hora sin ningun toque/click/scroll
/// mientras hay sesion iniciada, cierra la sesion. El router ya redirige
/// solo a /login apenas authProvider deja de estar autenticado.
class InactividadGuard extends ConsumerStatefulWidget {
  final Widget child;

  const InactividadGuard({super.key, required this.child});

  @override
  ConsumerState<InactividadGuard> createState() => _InactividadGuardState();
}

class _InactividadGuardState extends ConsumerState<InactividadGuard> {
  Timer? _timer;

  void _reiniciar() {
    _timer?.cancel();
    if (!ref.read(authProvider).autenticado) return;
    _timer = Timer(_tiempoInactividad, () {
      ref.read(authProvider.notifier).logout();
    });
  }

  @override
  void initState() {
    super.initState();
    _reiniciar();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.autenticado) {
        _reiniciar();
      } else {
        _timer?.cancel();
      }
    });

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _reiniciar(),
      onPointerMove: (_) => _reiniciar(),
      onPointerSignal: (_) => _reiniciar(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (_) {
          _reiniciar();
          return false;
        },
        child: widget.child,
      ),
    );
  }
}
