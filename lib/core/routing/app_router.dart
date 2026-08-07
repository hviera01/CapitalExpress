import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants/roles.dart';
import '../widgets/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/home/presentation/screens/admin_home_screen.dart';
import '../../features/home/presentation/screens/cobrador_home_screen.dart';
import '../../features/clientes/presentation/screens/clientes_list_screen.dart';
import '../../features/clientes/presentation/screens/cliente_form_screen.dart';
import '../../features/clientes/presentation/screens/cliente_resumen_screen.dart';
import '../../features/clientes/presentation/screens/cliente_detalle_screen.dart';
import '../../features/clientes/presentation/screens/reporte_clientes_screen.dart';
import '../../features/prestamos/presentation/screens/prestamos_list_screen.dart';
import '../../features/prestamos/presentation/screens/crear_prestamo_screen.dart';
import '../../features/prestamos/presentation/screens/prestamo_detalle_screen.dart';
import '../../features/prestamos/presentation/screens/editar_prestamo_screen.dart';
import '../../features/prestamos/presentation/screens/reporte_prestamos_screen.dart';
import '../../features/pagos/presentation/screens/historial_pagos_prestamo_screen.dart';
import '../../features/pagos/presentation/screens/reporte_cobros_screen.dart';
import '../../features/pagos/presentation/screens/cobros_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/reportes/presentation/screens/reportes_screen.dart';

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(authProvider, (previous, next) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final enLogin = state.matchedLocation == '/login';
      final enSplash = state.matchedLocation == '/';

      if (auth.cargando) {
        return enSplash ? null : '/';
      }

      if (!auth.autenticado) {
        return enLogin ? null : '/login';
      }

      final destino = auth.usuario!.rol == Roles.admin ? '/admin' : '/cobrador';
      if (enLogin || enSplash) return destino;
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/admin', builder: (context, state) => const AdminHomeScreen()),
      GoRoute(path: '/cobrador', builder: (context, state) => const CobradorHomeScreen()),
      GoRoute(
        path: '/clientes',
        builder: (context, state) => const ClientesListScreen(),
        routes: [
          GoRoute(
            path: 'nuevo',
            builder: (context, state) => const ClienteFormScreen(),
          ),
          GoRoute(
            path: 'reporte',
            builder: (context, state) => const ReporteClientesScreen(),
          ),
          GoRoute(
            path: ':id',
            builder: (context, state) =>
                ClienteResumenScreen(clienteId: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'editar',
                builder: (context, state) =>
                    ClienteFormScreen(clienteId: state.pathParameters['id']),
              ),
              GoRoute(
                path: 'detalle',
                builder: (context, state) =>
                    ClienteDetalleScreen(clienteId: state.pathParameters['id']!),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/prestamos',
        builder: (context, state) => const PrestamosListScreen(),
        routes: [
          GoRoute(
            path: 'nuevo',
            builder: (context, state) => CrearPrestamoScreen(
              clienteIdInicial: state.uri.queryParameters['clienteId'],
            ),
          ),
          GoRoute(
            path: ':id',
            builder: (context, state) =>
                PrestamoDetalleScreen(prestamoId: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'editar',
                builder: (context, state) =>
                    EditarPrestamoScreen(prestamoId: state.pathParameters['id']!),
              ),
              GoRoute(
                path: 'pagos',
                builder: (context, state) => HistorialPagosPrestamoScreen(
                  prestamoId: state.pathParameters['id']!,
                  numeroPrestamo: state.uri.queryParameters['numero'] ?? '',
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/cobros', builder: (context, state) => const CobrosScreen()),
      GoRoute(
        path: '/reportes',
        builder: (context, state) => const ReportesScreen(),
        routes: [
          GoRoute(
            path: 'prestamos',
            builder: (context, state) => const ReportePrestamosScreen(),
          ),
          GoRoute(
            path: 'cobros',
            builder: (context, state) => const ReporteCobrosScreen(),
          ),
          GoRoute(
            path: 'dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
        ],
      ),
    ],
  );
});
