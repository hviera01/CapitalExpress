import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/roles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ce_card.dart';
import '../../../../core/widgets/ce_scaffold.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../data/bitacora_model.dart';
import '../../providers/bitacora_provider.dart';

/// Bitacora de Seguridad (solo admin): quien elimino que y cuando --
/// clientes, prestamos y pagos. Agrupada por fecha (Hoy/Ayer/fecha),
/// mas reciente primero. Acotada a las ultimas 300 entradas (ver
/// BitacoraRepository.streamRecientes) para que cargue rapido incluso
/// con mucho historial.
class BitacoraScreen extends ConsumerWidget {
  const BitacoraScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(authProvider).usuario;
    final esAdmin = Roles.esAdminOEquivalente(usuario?.rol);

    if (!esAdmin) {
      return CeScaffold(
        appBar: AppBar(leading: const BackButton(), title: const Text('Bitácora de Seguridad')),
        body: const Center(child: Text('Solo administradores pueden ver la bitácora')),
      );
    }

    final entradasAsync = ref.watch(bitacoraStreamProvider);

    return CeScaffold(
      maxWidth: 900,
      appBar: AppBar(leading: const BackButton(), title: const Text('Bitácora de Seguridad')),
      body: entradasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error al cargar: $e')),
        data: (entradas) {
          if (entradas.isEmpty) {
            return const Center(child: Text('Todavía no hay movimientos registrados'));
          }
          final grupos = _agruparPorFecha(entradas);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Registro de eliminaciones (clientes, préstamos y pagos): quién, cuándo.',
                style: TextStyle(fontSize: 12, color: CEColors.textSecondary),
              ),
              const SizedBox(height: 16),
              for (final grupo in grupos.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, top: 8),
                  child: Text(
                    grupo.key,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: CEColors.textSecondary,
                        letterSpacing: 0.4),
                  ),
                ),
                CeCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < grupo.value.length; i++) ...[
                        if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                        _FilaBitacora(entrada: grupo.value[i]),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }

  Map<String, List<BitacoraModel>> _agruparPorFecha(List<BitacoraModel> entradas) {
    final hoy = DateTime.now();
    final grupos = <String, List<BitacoraModel>>{};
    for (final e in entradas) {
      final etiqueta = e.fecha != null ? _etiquetaFecha(e.fecha!, hoy) : 'Sin fecha';
      grupos.putIfAbsent(etiqueta, () => []).add(e);
    }
    return grupos;
  }

  String _etiquetaFecha(DateTime fecha, DateTime hoy) {
    final f = DateTime(fecha.year, fecha.month, fecha.day);
    final h = DateTime(hoy.year, hoy.month, hoy.day);
    final dif = h.difference(f).inDays;
    if (dif == 0) return 'HOY';
    if (dif == 1) return 'AYER';
    return DateFormat("d 'de' MMMM, yyyy", 'es').format(fecha).toUpperCase();
  }
}

(IconData, Color) _iconoAccion(String accion) {
  switch (accion) {
    case 'eliminar_cliente':
      return (Icons.person_off_outlined, CEColors.danger);
    case 'eliminar_prestamo':
    case 'eliminar_prestamo_permanente':
      return (Icons.delete_outline, CEColors.danger);
    case 'eliminar_pago':
      return (Icons.money_off_outlined, CEColors.danger);
    case 'editar_cliente':
      return (Icons.person_outline, CEColors.warning);
    case 'editar_prestamo':
      return (Icons.edit_outlined, CEColors.warning);
    case 'editar_usuario':
      return (Icons.manage_accounts_outlined, CEColors.warning);
    case 'aprobar_solicitud':
      return (Icons.check_circle_outline, CEColors.success);
    case 'rechazar_solicitud':
      return (Icons.cancel_outlined, CEColors.danger);
    default:
      return (Icons.history, CEColors.textSecondary);
  }
}

String _tituloAccion(String accion) {
  switch (accion) {
    case 'eliminar_cliente':
      return 'Cliente eliminado';
    case 'eliminar_prestamo':
      return 'Préstamo eliminado';
    case 'eliminar_prestamo_permanente':
      return 'Préstamo eliminado permanentemente';
    case 'eliminar_pago':
      return 'Pago eliminado';
    case 'editar_cliente':
      return 'Cliente editado';
    case 'editar_prestamo':
      return 'Préstamo editado';
    case 'editar_usuario':
      return 'Usuario editado';
    case 'aprobar_solicitud':
      return 'Solicitud aprobada';
    case 'rechazar_solicitud':
      return 'Solicitud rechazada';
    default:
      return 'Movimiento';
  }
}

class _FilaBitacora extends StatelessWidget {
  final BitacoraModel entrada;

  const _FilaBitacora({required this.entrada});

  @override
  Widget build(BuildContext context) {
    final (icono, color) = _iconoAccion(entrada.accion);
    final hora = entrada.fecha != null ? DateFormat('hh:mm a').format(entrada.fecha!) : '—';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icono, size: 17, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_tituloAccion(entrada.accion),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(entrada.descripcion,
                    style: const TextStyle(fontSize: 12.5, color: CEColors.textPrimary)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 12, color: CEColors.textSecondary),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        entrada.usuarioNombre.isEmpty ? 'Desconocido' : entrada.usuarioNombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: CEColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(hora, style: const TextStyle(fontSize: 11, color: CEColors.textSecondary)),
        ],
      ),
    );
  }
}
