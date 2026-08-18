import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/roles.dart';
import '../services/push_notifications_service.dart';
import '../theme/app_theme.dart';
import '../../features/auth/providers/auth_provider.dart';

/// Banner "Activar notificaciones" -- solo se muestra al rol
/// desarrollador (el unico que recibe push de tickets) cuando el
/// permiso todavia no esta concedido. Existe porque en iOS Safari el
/// permiso de notificaciones NO aparece si se pide automatico despues
/// del login (no cuenta como gesto directo del usuario) -- este boton
/// hace que el pedido salga del tap mismo, que ahi si funciona.
class CeBotonActivarPush extends ConsumerStatefulWidget {
  const CeBotonActivarPush({super.key});

  @override
  ConsumerState<CeBotonActivarPush> createState() => _CeBotonActivarPushState();
}

class _CeBotonActivarPushState extends ConsumerState<CeBotonActivarPush> {
  bool? _concedido;
  bool _activando = false;

  @override
  void initState() {
    super.initState();
    _revisar();
  }

  Future<void> _revisar() async {
    final concedido = await PushNotificationsService.permisoConcedido();
    if (mounted) setState(() => _concedido = concedido);
  }

  Future<void> _activar() async {
    setState(() => _activando = true);
    final usuario = ref.read(authProvider).usuario;
    final resultado = await PushNotificationsService.init(
      tipos: const ['tickets', 'solicitudes', 'permisos_edicion'],
      usuarioUid: usuario?.uid,
    );
    await _revisar();
    if (mounted) setState(() => _activando = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(resultado.detalle),
        backgroundColor: resultado.exito ? CEColors.success : CEColors.danger,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(authProvider).usuario;
    if (usuario?.rol != Roles.desarrollador) return const SizedBox.shrink();
    if (_concedido != false) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CEColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CEColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_off_outlined, color: CEColors.warning),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Activá las notificaciones para enterarte apenas llegue un ticket nuevo',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _activando ? null : _activar,
            child: _activando
                ? const SizedBox(
                    height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Activar'),
          ),
        ],
      ),
    );
  }
}
