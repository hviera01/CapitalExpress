import 'package:flutter/material.dart';

import '../services/cola_fotos_pendientes.dart';
import '../services/pendientes_sincronizar_service.dart';

/// Escucha PendientesSincronizarService (pagos/clientes disparados sin
/// esperar confirmacion) + ColaFotosPendientes (fotos de cliente sin
/// subir) y llama a [builder] con el total combinado -- para que
/// CeNavDrawer/CeWebShell puedan mostrar un aviso si algo sigue sin
/// sincronizar, en vez de que quede invisible.
class ContadorPendientesSync extends StatelessWidget {
  final Widget Function(BuildContext context, int total) builder;

  const ContadorPendientesSync({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(
        [PendientesSincronizarService.total, ColaFotosPendientes.cantidadPendiente],
      ),
      builder: (context, _) => builder(
        context,
        PendientesSincronizarService.total.value + ColaFotosPendientes.cantidadPendiente.value,
      ),
    );
  }
}
