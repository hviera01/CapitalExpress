import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/pago_model.dart';
import '../../../../core/models/solicitud_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/ce_dashboard_widgets.dart';
import '../../../../core/widgets/ce_menu_card.dart';
import '../../../../core/widgets/ce_menu_row.dart';
import '../../../../core/widgets/ce_section_label.dart';
import '../../../../core/widgets/ce_shell.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../clientes/providers/clientes_provider.dart';
import '../../../pagos/providers/pagos_provider.dart';
import '../../../prestamos/providers/prestamos_provider.dart';
import '../../../solicitudes/providers/solicitudes_provider.dart';

const _colorSubtitulo = Color(0xFF2DD9B8);

class CobradorHomeScreen extends ConsumerStatefulWidget {
  const CobradorHomeScreen({super.key});

  @override
  ConsumerState<CobradorHomeScreen> createState() => _CobradorHomeScreenState();
}

class _CobradorHomeScreenState extends ConsumerState<CobradorHomeScreen> {
  bool _cargando = true;
  double _valorCartera = 0;
  double _cobradoHoy = 0;
  int _clientesCount = 0;
  int _prestamosCount = 0;
  int _solicitudesCount = 0;
  List<PagoModel> _pagosRecientes = const [];
  List<SolicitudModel> _solicitudesRecientes = const [];

  @override
  void initState() {
    super.initState();
    if (esEscritorioWeb(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _cargarDashboard());
    }
  }

  Future<void> _cargarDashboard() async {
    final uid = ref.read(authProvider).usuario?.uid;
    if (uid == null) return;
    setState(() => _cargando = true);
    final prestamoRepo = ref.read(prestamoRepositoryProvider);
    final clienteRepo = ref.read(clienteRepositoryProvider);
    final pagoRepo = ref.read(pagoRepositoryProvider);
    final solicitudRepo = ref.read(solicitudRepositoryProvider);
    final hoy = DateTime.now();
    final hoyInicio = DateTime(hoy.year, hoy.month, hoy.day);

    try {
      final resultados = await Future.wait([
        prestamoRepo.sumarSaldoPendiente(cobradorUid: uid),
        clienteRepo.contar(cobradorUid: uid),
        prestamoRepo.contar(cobradorUid: uid),
        solicitudRepo.contarPendientes(cobradorUid: uid),
        pagoRepo.obtenerConRango(inicio: hoyInicio, fin: hoy, cobradorUid: uid),
        pagoRepo.obtenerRecientes(limite: 5, cobradorUid: uid),
        solicitudRepo.streamPendientes(cobradorUid: uid).first,
      ]);
      if (!mounted) return;
      final pagosHoy = resultados[4] as List<PagoModel>;
      setState(() {
        _valorCartera = resultados[0] as double;
        _clientesCount = resultados[1] as int;
        _prestamosCount = resultados[2] as int;
        _solicitudesCount = resultados[3] as int;
        _cobradoHoy = pagosHoy.fold<double>(0, (a, p) => a + p.total);
        _pagosRecientes = resultados[5] as List<PagoModel>;
        _solicitudesRecientes = (resultados[6] as List<SolicitudModel>).take(4).toList();
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(authProvider).usuario;
    final escritorio = esEscritorio(context);
    final columnas = escritorio ? 4 : 2;

    return CeAppShell(
      subtituloApp: 'PANEL DE COBRANZA',
      colorSubtitulo: _colorSubtitulo,
      tituloPagina: 'Panel de Cobranza',
      nombreUsuario: usuario?.nombre ?? '',
      rolUsuario: 'Cobrador',
      onLogout: () => ref.read(authProvider.notifier).logout(),
      body: esEscritorioWeb(context)
          ? _cuerpoEscritorio(context, usuario?.nombre ?? '')
          : ListView(
        padding: EdgeInsets.fromLTRB(
          escritorio ? 32 : 16,
          escritorio ? 0 : 16,
          escritorio ? 32 : 16,
          32,
        ),
        children: [
          if (!escritorio) ...[
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: CEColors.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.person_outline, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('¡Bienvenido!',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                            const SizedBox(height: 2),
                            Text(
                              usuario?.nombre ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(color: CEColors.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: CEColors.onlineDot,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1, color: CEColors.border),
            ),
          ],
          // Lo mas usado va arriba de todo.
          CeMenuRow(
            icono: Icons.notifications_active_outlined,
            titulo: 'Cobros',
            subtitulo: 'Cuotas vencidas y próximas',
            chevron: true,
            onTap: () => context.push('/cobros'),
          ),
          const CeSectionLabel('Opciones principales'),
          GridView.count(
            crossAxisCount: columnas,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.15,
            children: [
              CeMenuCard(
                icono: Icons.person_add_alt_1_outlined,
                titulo: 'Registrar Cliente',
                subtitulo: 'Alta de usuario',
                onTap: () => context.push('/clientes/nuevo'),
              ),
              CeMenuCard(
                icono: Icons.people_outline,
                titulo: 'Ver Clientes',
                subtitulo: 'Mi cartera',
                onTap: () => context.push('/clientes'),
              ),
              CeMenuCard(
                icono: Icons.account_balance_outlined,
                titulo: 'Ver Préstamos',
                subtitulo: 'Detalle créditos',
                onTap: () => context.push('/prestamos'),
              ),
              CeMenuCard(
                icono: Icons.payments_outlined,
                titulo: 'Mis Pagos',
                subtitulo: 'Recaudación',
                onTap: () => context.push('/reportes/cobros'),
              ),
            ],
          ),
          const CeSectionLabel('Gestión y servicios'),
          CeMenuRow(
            icono: Icons.add_card_outlined,
            titulo: 'Solicitar Préstamo',
            subtitulo: 'Crear nueva solicitud',
            chevron: true,
            onTap: () => context.push('/prestamos/solicitar'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Panel de escritorio Web: ver AdminHomeScreen._cuerpoEscritorio
  /// (mismo patron), con los datos acotados a la cartera de este
  /// cobrador en vez de todo el sistema.
  Widget _cuerpoEscritorio(BuildContext context, String nombreUsuario) {
    final hora = DateTime.now().hour;
    final saludo = hora < 12 ? 'Buenos días' : (hora < 19 ? 'Buenas tardes' : 'Buenas noches');

    return RefreshIndicator(
      onRefresh: _cargarDashboard,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
        children: [
          LayoutBuilder(builder: (context, constraints) {
            final angosto = constraints.maxWidth < 900;
            final izquierda = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CeDashboardHeader(
                  saludo: '$saludo, ${nombreUsuario.isEmpty ? '' : nombreUsuario.split(' ').first}.',
                ),
                const SizedBox(height: 20),
                CeAccionesRapidasFila(
                  acciones: [
                    CeAccionRapidaTile(
                        icono: Icons.notifications_active_outlined,
                        titulo: 'Cobros',
                        onTap: () => context.push('/cobros')),
                    CeAccionRapidaTile(
                        icono: Icons.person_add_alt_1_outlined,
                        titulo: 'Registrar Cliente',
                        color: CEColors.warning,
                        onTap: () => context.push('/clientes/nuevo')),
                    CeAccionRapidaTile(
                        icono: Icons.add_card_outlined,
                        titulo: 'Solicitar Préstamo',
                        color: CEColors.accent,
                        onTap: () => context.push('/prestamos/solicitar')),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('MI CARTERA',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: CEColors.textSecondary,
                        letterSpacing: 0.4)),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 3.1,
                  children: [
                    CeTarjetaExplorar(
                      icono: Icons.people_outline,
                      titulo: 'Ver Clientes',
                      valor: _cargando ? '…' : '$_clientesCount',
                      subtitulo: 'en mi cartera',
                      enlace: 'Directorio',
                      onTap: () => context.push('/clientes'),
                    ),
                    CeTarjetaExplorar(
                      icono: Icons.account_balance_outlined,
                      titulo: 'Ver Préstamos',
                      valor: _cargando ? '…' : '$_prestamosCount',
                      subtitulo: 'préstamos asignados',
                      enlace: 'Gestionar',
                      onTap: () => context.push('/prestamos'),
                    ),
                    CeTarjetaExplorar(
                      icono: Icons.payments_outlined,
                      titulo: 'Mis Pagos',
                      valor: '',
                      subtitulo: 'Historial de recaudación',
                      enlace: 'Ver',
                      onTap: () => context.push('/reportes/cobros'),
                    ),
                    CeTarjetaExplorar(
                      icono: Icons.forum_outlined,
                      titulo: 'Mis Solicitudes',
                      valor: _cargando ? '…' : '$_solicitudesCount',
                      subtitulo: 'pendientes de aprobación',
                      enlace: 'Ver',
                      onTap: () => context.push('/solicitudes'),
                    ),
                  ],
                ),
              ],
            );

            final derecha = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CeTarjetaValor(
                  etiqueta: 'Mi cartera',
                  valor: _cargando ? '…' : formatearLempiras(_valorCartera),
                ),
                const SizedBox(height: 16),
                CeTarjetaDestacada(
                  etiqueta: 'Cobrado hoy',
                  valor: _cargando ? '…' : formatearLempiras(_cobradoHoy),
                ),
                const SizedBox(height: 16),
                CePanelActividad(
                  titulo: 'Actividad reciente',
                  onRefrescar: _cargarDashboard,
                  onVerTodo: () => context.push('/reportes/cobros'),
                  items: _cargando
                      ? const []
                      : [
                          ..._pagosRecientes.map((p) => CeActividadItem(
                                icono: Icons.payments_outlined,
                                color: CEColors.success,
                                titulo: 'Abono recibido: ${formatearLempiras(p.total)}',
                                subtitulo: p.clienteNombre,
                                tiempo: p.fechaPago != null
                                    ? tiempoRelativoCorto(p.fechaPago!.toDate())
                                    : '',
                              )),
                          ..._solicitudesRecientes.map((s) => CeActividadItem(
                                icono: Icons.forum_outlined,
                                color: CEColors.accent,
                                titulo: 'Solicitud enviada: ${formatearLempiras(s.monto)}',
                                subtitulo: s.cliente,
                                tiempo: s.fechaCreacion != null
                                    ? tiempoRelativoCorto(s.fechaCreacion!.toDate())
                                    : '',
                              )),
                        ],
                ),
              ],
            );

            if (angosto) {
              return Column(children: [izquierda, const SizedBox(height: 20), derecha]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: izquierda),
                const SizedBox(width: 20),
                SizedBox(width: 300, child: derecha),
              ],
            );
          }),
        ],
      ),
    );
  }
}
