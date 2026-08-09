import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/web_tabs_provider.dart';
import 'ce_web_shell.dart';
import '../../features/bitacora/presentation/screens/bitacora_screen.dart';
import '../../features/clientes/presentation/screens/clientes_list_screen.dart';
import '../../features/dispositivos/presentation/screens/dispositivos_screen.dart';
import '../../features/pagos/presentation/screens/cobros_screen.dart';
import '../../features/pagos/presentation/screens/reporte_cobros_screen.dart';
import '../../features/prestamos/presentation/screens/prestamos_list_screen.dart';
import '../../features/reportes/presentation/screens/reportes_screen.dart';
import '../../features/solicitudes/presentation/screens/solicitudes_screen.dart';
import '../../features/usuarios/presentation/screens/usuarios_list_screen.dart';

/// Una seccion de nivel superior que puede abrirse como pestaña en
/// escritorio Web (ver CeWebShell). Lista unica y compartida: tanto el
/// menu lateral como cualquier link "ir a Cobros"/"Ver Clientes" desde
/// DENTRO de una pestaña (ej. el panel principal) usan esta misma
/// definicion, para no duplicar el mapeo id->pantalla en mas de un
/// lado.
class CeSeccionWeb {
  final String id;
  final String titulo;
  final IconData icono;
  final WidgetBuilder construir;

  const CeSeccionWeb({
    required this.id,
    required this.titulo,
    required this.icono,
    required this.construir,
  });
}

const Map<String, CeSeccionWeb> ceSeccionesWeb = {
  'clientes': CeSeccionWeb(
    id: 'clientes',
    titulo: 'Clientes',
    icono: Icons.people_outline,
    construir: _clientes,
  ),
  'prestamos': CeSeccionWeb(
    id: 'prestamos',
    titulo: 'Préstamos',
    icono: Icons.account_balance_outlined,
    construir: _prestamos,
  ),
  'cobros': CeSeccionWeb(
    id: 'cobros',
    titulo: 'Cobros',
    icono: Icons.notifications_outlined,
    construir: _cobros,
  ),
  'solicitudes': CeSeccionWeb(
    id: 'solicitudes',
    titulo: 'Solicitudes',
    icono: Icons.assignment_outlined,
    construir: _solicitudes,
  ),
  'reportes': CeSeccionWeb(
    id: 'reportes',
    titulo: 'Reportes',
    icono: Icons.bar_chart_outlined,
    construir: _reportes,
  ),
  'usuarios': CeSeccionWeb(
    id: 'usuarios',
    titulo: 'Usuarios',
    icono: Icons.manage_accounts_outlined,
    construir: _usuarios,
  ),
  'dispositivos': CeSeccionWeb(
    id: 'dispositivos',
    titulo: 'Dispositivos',
    icono: Icons.devices_outlined,
    construir: _dispositivos,
  ),
  'bitacora': CeSeccionWeb(
    id: 'bitacora',
    titulo: 'Bitácora',
    icono: Icons.shield_outlined,
    construir: _bitacora,
  ),
  'mis-pagos': CeSeccionWeb(
    id: 'mis-pagos',
    titulo: 'Mis Pagos',
    icono: Icons.payments_outlined,
    construir: _misPagos,
  ),
};

Widget _clientes(BuildContext context) => const ClientesListScreen();
Widget _prestamos(BuildContext context) => const PrestamosListScreen();
Widget _cobros(BuildContext context) => const CobrosScreen();
Widget _solicitudes(BuildContext context) => const SolicitudesScreen();
Widget _reportes(BuildContext context) => const ReportesScreen();
Widget _usuarios(BuildContext context) => const UsuariosListScreen();
Widget _dispositivos(BuildContext context) => const DispositivosScreen();
Widget _bitacora(BuildContext context) => const BitacoraScreen();
Widget _misPagos(BuildContext context) => const ReporteCobrosScreen();

/// Abre (o enfoca, si ya estaba abierta) una seccion como pestaña --
/// usar esto en vez de `context.push('/ruta')` para cualquier link
/// DENTRO de una pestaña que apunte a otra seccion de nivel superior
/// (Cobros, Ver Clientes, etc.), asi esa navegacion tambien queda
/// instantanea en vez de abrir una pantalla nueva encima de todo.
void abrirSeccionWeb(WidgetRef ref, String id) {
  final seccion = ceSeccionesWeb[id];
  if (seccion == null) return;
  ref.read(webTabsProvider.notifier).abrir(WebTabItem(
        id: seccion.id,
        titulo: seccion.titulo,
        icono: seccion.icono,
        contenido: envolverConNavegador(seccion.construir),
      ));
}
