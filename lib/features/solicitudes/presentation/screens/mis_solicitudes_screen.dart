import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/solicitud_edicion_model.dart';
import '../../../../core/models/solicitud_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/widgets/ce_card.dart';
import '../../../../core/widgets/ce_scaffold.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../clientes/presentation/screens/cliente_form_screen.dart';
import '../../../clientes/providers/clientes_provider.dart';
import '../../../prestamos/presentation/screens/editar_prestamo_screen.dart';
import '../../../prestamos/providers/prestamos_provider.dart';
import '../../providers/solicitud_edicion_provider.dart';
import '../../providers/solicitudes_provider.dart';

/// "Mis Solicitudes": lo que un cobrador mando -- solicitudes de
/// prestamo (solo se ven las pendientes, las decididas se borran del
/// todo, ver SolicitudRepository) y solicitudes de edicion (se ven
/// TODAS con su estado, incluida la ventana de 1h para editar cuando
/// esta aprobada -- desde aca mismo se puede entrar a concretar la
/// edicion sin tener que volver a buscar el cliente/prestamo).
class MisSolicitudesScreen extends ConsumerStatefulWidget {
  const MisSolicitudesScreen({super.key});

  @override
  ConsumerState<MisSolicitudesScreen> createState() => _MisSolicitudesScreenState();
}

class _MisSolicitudesScreenState extends ConsumerState<MisSolicitudesScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Refresca la cuenta regresiva de los permisos aprobados sin que
    // haga falta salir y volver a entrar a la pantalla.
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _tiempoRestante(SolicitudEdicionModel s) {
    final expira = s.fechaExpiraPermiso?.toDate();
    if (expira == null) return '';
    final restante = expira.difference(DateTime.now());
    if (restante.isNegative) return 'Vence en breve';
    if (restante.inMinutes < 1) return 'Menos de 1 minuto';
    if (restante.inMinutes < 60) return '${restante.inMinutes} min restantes';
    return '${restante.inHours}h ${restante.inMinutes % 60}min restantes';
  }

  Future<void> _editarAhora(SolicitudEdicionModel s) async {
    if (s.entidadTipo == 'cliente') {
      final cliente = await ref.read(clienteRepositoryProvider).obtenerPorId(s.entidadId);
      if (!mounted) return;
      if (cliente == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Ese cliente ya no existe')));
        return;
      }
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ClienteFormScreen(
          clienteId: cliente.id,
          clienteInicial: cliente,
          valoresPropuestos: s.valoresNuevos,
          solicitudEdicionId: s.id,
        ),
      ));
    } else {
      final prestamo = await ref.read(prestamoRepositoryProvider).obtenerPorId(s.entidadId);
      if (!mounted) return;
      if (prestamo == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Ese préstamo ya no existe')));
        return;
      }
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => EditarPrestamoScreen(
          prestamoId: prestamo.prestamoId,
          prestamoInicial: prestamo,
          valoresPropuestos: s.valoresNuevos,
          solicitudEdicionId: s.id,
        ),
      ));
    }
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'aprobada':
        return CEColors.success;
      case 'rechazada':
      case 'vencida':
        return CEColors.danger;
      case 'aplicada':
        return CEColors.accent;
      default:
        return CEColors.warning;
    }
  }

  String _etiquetaEstado(String estado) {
    switch (estado) {
      case 'aprobada':
        return 'APROBADA — LISTA PARA EDITAR';
      case 'rechazada':
        return 'RECHAZADA';
      case 'aplicada':
        return 'YA APLICADA';
      case 'vencida':
        return 'VENCIDA';
      default:
        return 'PENDIENTE';
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(authProvider).usuario;
    final uid = usuario?.uid;
    final f = DateFormat('dd/MM/yyyy hh:mm a');

    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Sesión no encontrada')));
    }

    return StreamBuilder<List<SolicitudModel>>(
      stream: ref.read(solicitudRepositoryProvider).streamPendientes(cobradorUid: uid),
      builder: (context, snapPrestamo) {
        final prestamoSolicitudes = snapPrestamo.data ?? const [];
        return StreamBuilder<List<SolicitudEdicionModel>>(
          stream: ref.read(solicitudEdicionRepositoryProvider).streamPorSolicitante(uid),
          builder: (context, snapEdicion) {
            final edicionSolicitudes = snapEdicion.data ?? const [];
            final cargando = snapPrestamo.connectionState == ConnectionState.waiting ||
                snapEdicion.connectionState == ConnectionState.waiting;

            return CeScaffold(
              maxWidth: 900,
              appBar: AppBar(leading: const BackButton(), title: const Text('Mis Solicitudes')),
              body: cargando
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const Text('Solicitudes de préstamo',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 4),
                        const Text(
                            'Solo se muestran las pendientes -- una vez decidida (aprobada o rechazada), el préstamo aparece en Ver Préstamos o la solicitud desaparece.',
                            style: TextStyle(fontSize: 11, color: CEColors.textSecondary)),
                        const SizedBox(height: 12),
                        if (prestamoSolicitudes.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text('No tenés solicitudes de préstamo pendientes',
                                style: TextStyle(color: CEColors.textSecondary)),
                          )
                        else
                          ...prestamoSolicitudes.map((s) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: CeCard(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(s.cliente,
                                                style: const TextStyle(fontWeight: FontWeight.w700)),
                                            const SizedBox(height: 2),
                                            Text(formatearLempiras(s.monto),
                                                style: const TextStyle(
                                                    fontSize: 12, color: CEColors.textSecondary)),
                                          ],
                                        ),
                                      ),
                                      const _ChipEstado(texto: 'PENDIENTE', color: CEColors.warning),
                                    ],
                                  ),
                                ),
                              )),
                        const SizedBox(height: 24),
                        const Text('Solicitudes de edición',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 12),
                        if (edicionSolicitudes.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: Text('No mandaste solicitudes de edición',
                                style: TextStyle(color: CEColors.textSecondary)),
                          )
                        else
                          ...edicionSolicitudes.map((s) {
                            final activa = s.permisoVigente;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: CeCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                            s.entidadTipo == 'cliente'
                                                ? Icons.person_outline
                                                : Icons.credit_card_outlined,
                                            size: 16,
                                            color: CEColors.primary),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(s.entidadNombre,
                                              style: const TextStyle(fontWeight: FontWeight.w700)),
                                        ),
                                        _ChipEstado(
                                            texto: _etiquetaEstado(s.estado),
                                            color: _colorEstado(s.estado)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text('${s.valoresNuevos.length} campo(s) a cambiar',
                                        style: const TextStyle(
                                            fontSize: 12, color: CEColors.textSecondary)),
                                    if (s.fechaCreacion != null)
                                      Text('Enviada el ${f.format(s.fechaCreacion!.toDate())}',
                                          style: const TextStyle(
                                              fontSize: 11, color: CEColors.textSecondary)),
                                    if (s.estado == 'rechazada' &&
                                        (s.motivoRechazo?.isNotEmpty ?? false))
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text('Motivo: ${s.motivoRechazo}',
                                            style: const TextStyle(
                                                fontSize: 12, color: CEColors.danger)),
                                      ),
                                    if (activa) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.timer_outlined,
                                              size: 14, color: CEColors.success),
                                          const SizedBox(width: 4),
                                          Text(_tiempoRestante(s),
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: CEColors.success)),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          icon: const Icon(Icons.edit_outlined),
                                          label: const Text('Editar ahora'),
                                          onPressed: () => _editarAhora(s),
                                        ),
                                      ),
                                    ],
                                    if (s.estado == 'aprobada' && !activa) ...[
                                      const SizedBox(height: 6),
                                      const Text('El permiso ya venció',
                                          style: TextStyle(fontSize: 12, color: CEColors.danger)),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
            );
          },
        );
      },
    );
  }
}

class _ChipEstado extends StatelessWidget {
  final String texto;
  final Color color;

  const _ChipEstado({required this.texto, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(texto,
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w800)),
    );
  }
}
