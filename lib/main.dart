import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/inactividad_guard.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Todos los DateFormat(...) de la app (recibos, tablas, filtros de
  // fecha) usan el locale por defecto de intl -- sin esto salian en
  // ingles (nombres de mes, AM/PM) aunque el patron fuera el mismo.
  await initializeDateFormatting('es');
  Intl.defaultLocale = 'es';
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Cache local persistente SIN limite de tamano: con el limite por
  // defecto (40MB) Firestore empieza a purgar documentos viejos del
  // cache una vez lleno, asi que pantallas ya visitadas volvian a pedir
  // todo al servidor igual. Sin ese limite, una segunda visita a
  // cualquier pantalla ya cargada se sirve del disco/IndexedDB al
  // instante mientras se sincroniza en segundo plano con el servidor.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
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
      // Sin esto, el selector de fecha (y cualquier otro widget de
      // Material con texto localizado) sale en ingles por defecto.
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (context, child) => InactividadGuard(child: child!),
    );
  }
}
