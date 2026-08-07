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
            path: ':id',
            builder: (context, state) =>
                ClienteFormScreen(clienteId: state.pathParameters['id']),
          ),
        ],
      ),
    ],
  );
});
