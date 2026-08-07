import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/inactividad_guard.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Cache local persistente: sin esto, cada navegacion vuelve a pedirle
  // todo al servidor (mas lento y se nota, sobre todo en web). Con la
  // cache, una segunda visita a la misma pantalla se siente instantanea.
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
  runApp(const ProviderScope(child: CapitalExpressApp()));
}

class CapitalExpressApp extends ConsumerWidget {
  const CapitalExpressApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Capital Express',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      builder: (context, child) => InactividadGuard(child: child!),
    );
  }
}
