import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/models/pago_model.dart';
import '../../../../core/models/solicitud_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/ce_dashboard_widgets.dart';
import '../../../../core/widgets/ce_dashed_card.dart';
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

class AdminHomeScreen extends ConsumerStatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  ConsumerState<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends ConsumerState<AdminHomeScreen> {
  bool _cargando = true;
  double _valorPortafolio = 0;
  double _cobradoHoy = 0;
  int _clientesCount = 0;
  int _prestamosCount = 0;
  int _solicitudesCount = 0;
  List<PagoModel> _pagosRecientes = const [];
  List<SolicitudModel> _solicitudesRecientes = const [];

  @override
  void initState() {
    super.initState();
    // Los datos del dashboard (valor de cartera, cobrado hoy, etc.)
    // solo se usan en el diseno de escritorio Web -- en mobile/Windows
    // no hace falta gastar esas consultas.
    if (esEscritorioWeb(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _cargarDashboard());
    }
  }

  Future<void> _cargarDashboard() async {
    setState(() => _cargando = true);
    final prestamoRepo = ref.read(prestamoRepositoryProvider);
    final clienteRepo = ref.read(clienteRepositoryProvider);
    final pagoRepo = ref.read(pagoRepositoryProvider);
    final solicitudRepo = ref.read(solicitudRepositoryProvider);
    final hoy = DateTime.now();
    final hoyInicio = DateTime(hoy.year, hoy.month, hoy.day);

    try {
      final resultados = await Future.wait([
        prestamoRepo.sumarSaldoPendiente(),
        clienteRepo.contar(),
        prestamoRepo.contar(),
        solicitudRepo.contarPendientes(),
        pagoRepo.obtenerConRango(inicio: hoyInicio, fin: hoy),
        pagoRepo.obtenerRecientes(limite: 5),
        solicitudRepo.streamPendientes().first,
      ]);
      if (!mounted) return;
      final pagosHoy = resultados[4] as List<PagoModel>;
      setState(() {
        _valorPortafolio = resultados[0] as double;
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

  void _proximamente(BuildContext context, String modulo) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$modulo - próximamente')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = ref.watch(authProvider).usuario;
    final escritorio = esEscritorio(context);
    final columnas = escritorio ? 4 : 2;

    return CeAppShell(
      subtituloApp: 'ADMIN PANEL',
      colorSubtitulo: _colorSubtitulo,
      tituloPagina: 'Panel Administrador',
      nombreUsuario: usuario?.nombre ?? '',
      rolUsuario: 'Administrador',
      onLogout: () => ref.read(authProvider.notifier).logout(),
      onNotificaciones: () => context.push('/cobros'),
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
          CeMenuRow(
            icono: Icons.notifications_outlined,
            titulo: 'Cobros',
            subtitulo: 'Cuotas vencidas y próximas',
            chevron: true,
            onTap: () => context.push('/cobros'),
          ),
          const CeSectionLabel('Crear'),
          GridView.count(
            crossAxisCount: columnas,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.15,
            children: [
              CeMenuCard(
                icono: Icons.add,
                titulo: 'Crear Préstamo',
                subtitulo: 'Nueva solicitud',
                onTap: () => context.push('/prestamos/nuevo'),
              ),
              CeMenuCard(
                icono: Icons.person_add_alt_1_outlined,
                titulo: 'Crear Cliente',
                subtitulo: 'Alta de usuario',
                onTap: () => context.push('/clientes/nuevo'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CeMenuRow(
            icono: Icons.badge_outlined,
            titulo: 'Crear Usuario',
            subtitulo: 'Gestión interna',
            chevron: true,
            onTap: () => context.push('/usuarios/nuevo'),
          ),
          const CeSectionLabel('Visualizar'),
          GridView.count(
            crossAxisCount: columnas,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.15,
            children: [
              CeMenuCard(
                oscuro: true,
                icono: Icons.forum_outlined,
                titulo: 'Solicitudes',
                subtitulo: '',
                onTap: () => context.push('/solicitudes'),
              ),
              CeMenuCard(
                icono: Icons.people_outline,
                titulo: 'Ver Clientes',
                subtitulo: '',
                onTap: () => context.push('/clientes'),
              ),
              CeMenuCard(
                icono: Icons.account_balance_outlined,
                titulo: 'Ver Préstamos',
                subtitulo: '',
                onTap: () => context.push('/prestamos'),
              ),
              CeMenuCard(
                icono: Icons.manage_accounts_outlined,
                titulo: 'Ver Usuarios',
                subtitulo: '',
                onTap: () => context.push('/usuarios'),
              ),
              CeMenuCard(
                icono: Icons.devices_outlined,
                titulo: 'Dispositivos',
                subtitulo: '',
                onTap: () => context.push('/dispositivos'),
              ),
            ],
          ),
          const CeSectionLabel('Reportes'),
          CeMenuRow(
            icono: Icons.summarize_outlined,
            titulo: 'Reportes',
            subtitulo: 'Clientes, préstamos, cobros y dashboard',
            chevron: true,
            onTap: () => context.push('/reportes'),
          ),
          // "Buscar Actualizaciones" no aplica en Web (ver
          // ActualizacionService.aplica) -- ahi esa tarjeta era solo un
          // adorno sin funcion real, se saca del todo.
          if (!kIsWeb) ...[
            const SizedBox(height: 12),
            CeDashedCard(
              onTap: () => _proximamente(context, 'Buscar Actualizaciones'),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration:
                        const BoxDecoration(color: CEColors.iconBadgeBg, shape: BoxShape.circle),
                    child: const Icon(Icons.history_toggle_off, color: CEColors.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Buscar Actualizaciones',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        SizedBox(height: 2),
                        Text('Revisar si hay una nueva versión de la app',
                            style: TextStyle(fontSize: 12, color: CEColors.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: CEColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'v1.0.0',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Panel de escritorio Web: saludo arriba (ancho completo), acciones
  /// rapidas en una fila que llena el ancho, tarjetas de "explorar" con
  /// datos en vivo mas chicas, y a la derecha SIEMPRE el valor de
  /// cartera + cobrado hoy + actividad reciente juntos en una sola
  /// seccion -- ya no es la grilla de tarjetas grandes de mobile/
  /// Windows reacomodada.
  Widget _cuerpoEscritorio(BuildContext context, String nombreUsuario) {
    final hora = DateTime.now().hour;
    final saludo = hora < 12 ? 'Buenos días' : (hora < 19 ? 'Buenas tardes' : 'Buenas noches');

    return RefreshIndicator(
      onRefresh: _cargarDashboard,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
        children: [
          CeDashboardHeader(
            saludo: '$saludo, ${nombreUsuario.isEmpty ? 'Admin' : nombreUsuario.split(' ').first}.',
            subtitulo: 'Esto es lo que está pasando hoy en Capital Express.',
          ),
          const SizedBox(height: 20),
          CeAccionesRapidasFila(
            acciones: [
              CeAccionRapidaTile(
                  icono: Icons.notifications_outlined, titulo: 'Cobros', onTap: () => context.push('/cobros')),
              CeAccionRapidaTile(
                  icono: Icons.add,
                  titulo: 'Crear Préstamo',
                  color: CEColors.accent,
                  onTap: () => context.push('/prestamos/nuevo')),
              CeAccionRapidaTile(
                  icono: Icons.person_add_alt_1_outlined,
                  titulo: 'Crear Cliente',
                  color: CEColors.warning,
                  onTap: () => context.push('/clientes/nuevo')),
              CeAccionRapidaTile(
                  icono: Icons.badge_outlined,
                  titulo: 'Crear Usuario',
                  color: CEColors.textSecondary,
                  onTap: () => context.push('/usuarios/nuevo')),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(builder: (context, constraints) {
            final angosto = constraints.maxWidth < 900;
            final izquierda = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('EXPLORAR PORTAFOLIO',
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
                  childAspectRatio: 2.0,
                  children: [
                    CeTarjetaExplorar(
                      icono: Icons.forum_outlined,
                      titulo: 'Solicitudes',
                      valor: _cargando ? '…' : '$_solicitudesCount',
                      subtitulo: 'pendientes de revisión',
                      enlace: 'Ver todas',
                      onTap: () => context.push('/solicitudes'),
                    ),
                    CeTarjetaExplorar(
                      icono: Icons.people_outline,
                      titulo: 'Ver Clientes',
                      valor: _cargando ? '…' : '$_clientesCount',
                      subtitulo: 'perfiles activos',
                      enlace: 'Directorio',
                      onTap: () => context.push('/clientes'),
                    ),
                    CeTarjetaExplorar(
                      icono: Icons.account_balance_outlined,
                      titulo: 'Ver Préstamos',
                      valor: _cargando ? '…' : '$_prestamosCount',
                      subtitulo: 'préstamos registrados',
                      enlace: 'Gestionar',
                      onTap: () => context.push('/prestamos'),
                    ),
                    CeTarjetaExplorar(
                      icono: Icons.summarize_outlined,
                      titulo: 'Reportes',
                      valor: '',
                      subtitulo: 'Financiero y por cobrador',
                      enlace: 'Generar',
                      onTap: () => context.push('/reportes'),
                    ),
                    CeTarjetaExplorar(
                      icono: Icons.manage_accounts_outlined,
                      titulo: 'Usuarios',
                      valor: '',
                      subtitulo: 'Gestión interna',
                      enlace: 'Ver',
                      onTap: () => context.push('/usuarios'),
                    ),
                    CeTarjetaExplorar(
                      icono: Icons.devices_outlined,
                      titulo: 'Dispositivos',
                      valor: '',
                      subtitulo: 'Equipos con acceso',
                      enlace: 'Ver',
                      onTap: () => context.push('/dispositivos'),
                    ),
                  ],
                ),
              ],
            );

            final derecha = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CeTarjetaValor(
                  etiqueta: 'Valor de cartera',
                  valor: _cargando ? '…' : formatearLempiras(_valorPortafolio),
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
                                subtitulo:
                                    '${p.clienteNombre} · ${p.nombreCobrador.isEmpty ? 'N/D' : p.nombreCobrador}',
                                tiempo: p.fechaPago != null
                                    ? tiempoRelativoCorto(p.fechaPago!.toDate())
                                    : '',
                              )),
                          ..._solicitudesRecientes.map((s) => CeActividadItem(
                                icono: Icons.forum_outlined,
                                color: CEColors.accent,
                                titulo: 'Nueva solicitud: ${formatearLempiras(s.monto)}',
                                subtitulo: '${s.cliente} · ${s.cobradorSolicitante}',
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
