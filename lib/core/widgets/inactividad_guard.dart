import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/roles.dart';
import '../providers/actualizacion_provider.dart';
import '../providers/web_tabs_provider.dart';
import '../routing/app_router.dart';
import '../services/actualizacion_service.dart';
import '../services/push_notifications_service.dart';
import '../version_app.dart';
import '../widgets/actualizacion_dialog.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/dispositivos/providers/dispositivos_provider.dart';

const _tiempoInactividad = Duration(hours: 1);
const _intervaloChequeoActualizacion = Duration(minutes: 10);

/// Envuelve toda la app (por encima del Navigator, en el `builder` de
/// MaterialApp.router): si pasa una hora sin ningun toque/click/scroll
/// mientras hay sesion iniciada, cierra la sesion. El router ya redirige
/// solo a /login apenas authProvider deja de estar autenticado.
///
/// Tambien dispara el chequeo automatico de actualizaciones (solo
/// Windows/Android, ver ActualizacionService) apenas hay sesion, y cada
/// 10 minutos mientras siga abierta -- va aca (no en un StatefulWidget
/// de pantalla) porque esta app no tiene un "shell" persistente: cada
/// pantalla se desmonta al navegar a otra, pero InactividadGuard sigue
/// montado todo el tiempo que dure la sesion.
class InactividadGuard extends ConsumerStatefulWidget {
  final Widget child;

  const InactividadGuard({super.key, required this.child});

  @override
  ConsumerState<InactividadGuard> createState() => _InactividadGuardState();
}

class _InactividadGuardState extends ConsumerState<InactividadGuard> {
  Timer? _timer;
  Timer? _timerActualizacion;
  bool _dialogoActualizacionAbierto = false;

  void _reiniciar() {
    _timer?.cancel();
    if (!ref.read(authProvider).autenticado) return;
    _timer = Timer(_tiempoInactividad, () {
      ref.read(authProvider.notifier).logout();
    });
  }

  /// Registra este equipo en el modulo de Dispositivos (ver
  /// DispositivoRepository.reportar) -- version instalada + quien
  /// inicio sesion ahora. Igual que el chequeo de actualizaciones, va
  /// aca porque es el unico widget que vive durante toda la sesion.
  void _reportarDispositivo() {
    final usuario = ref.read(authProvider).usuario;
    ref.read(dispositivoRepositoryProvider).reportar(
          versionApp: versionApp,
          usuario: usuario?.nombre ?? '',
        );
  }

  /// Notificacion push segun rol:
  /// - "desarrollador" (rol exclusivo para esto, no cualquier admin):
  ///   recibe avisos de TICKETS nuevos, en cualquier plataforma.
  /// - "admin" (cualquier cuenta admin): recibe avisos de SOLICITUDES
  ///   nuevas (necesitan su aprobacion), pero SOLO en Android -- asi
  ///   se pidio, para no repetir la complicacion de permisos de iOS
  ///   Safari con cada admin.
  /// - desarrollador tambien recibe solicitudes (tiene los mismos
  ///   permisos que admin en todo lo demas).
  /// Ver PushNotificationsService.
  void _iniciarPushSegunRol() {
    final usuario = ref.read(authProvider).usuario;
    if (usuario == null) return;
    final tipos = <String>[];
    if (usuario.rol == Roles.desarrollador) {
      tipos.addAll(['tickets', 'solicitudes']);
    } else if (usuario.rol == Roles.admin && !kIsWeb) {
      tipos.add('solicitudes');
    }
    if (tipos.isNotEmpty) PushNotificationsService.init(tipos: tipos);
  }

  void _iniciarChequeoActualizacion() {
    if (!ActualizacionService.aplica) return;
    _chequearActualizacion();
    _timerActualizacion?.cancel();
    _timerActualizacion = Timer.periodic(_intervaloChequeoActualizacion, (_) => _chequearActualizacion());
  }

  Future<void> _chequearActualizacion() async {
    if (_dialogoActualizacionAbierto) return;
    final actualizacion = await ActualizacionService.buscarActualizacion();
    final context = rootNavigatorKey.currentContext;
    if (actualizacion == null || context == null || !context.mounted) return;
    ref.read(actualizacionDisponibleProvider.notifier).establecer(actualizacion);
    _dialogoActualizacionAbierto = true;
    await mostrarDialogoActualizacion(context, actualizacion);
    _dialogoActualizacionAbierto = false;
  }

  @override
  void initState() {
    super.initState();
    _reiniciar();
    if (ref.read(authProvider).autenticado) {
      _iniciarChequeoActualizacion();
      _reportarDispositivo();
      _iniciarPushSegunRol();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timerActualizacion?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.autenticado) {
        _reiniciar();
        if (previous?.autenticado != true) {
          _iniciarChequeoActualizacion();
          _reportarDispositivo();
          _iniciarPushSegunRol();
        }
      } else {
        _timer?.cancel();
        _timerActualizacion?.cancel();
        ref.read(webTabsProvider.notifier).limpiar();
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
