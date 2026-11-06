import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// SIEG Design System (Modern Fintech Minimalism) — mismos
/// tokens usados en la app Kotlin original (ui/theme/DesignSystem.kt),
/// portados para que ambas apps se vean identicas.
class CEColors {
  CEColors._();

  static const Color primary = Color(0xFF0A192F); // navy
  static const Color primaryDark = Color(0xFF0B1C30); // navy mas oscuro (hero cards)
  static const Color accent = Color(0xFF007AFF); // blue
  static const Color surface = Color(0xFFF8FAFC);
  static const Color border = Color(0xFFE2E8F0);
  static const Color success = Color(0xFF16A34A);
  static const Color onlineDot = Color(0xFF64FFDA); // verde-agua, punto "en linea"
  static const Color danger = Color(0xFFDC2626);
  static const Color pill = Color(0xFFF43F5E); // rosa/rojo de badges "N NUEVAS"
  static const Color warning = Color(0xFFD97706);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color iconBadgeBg = Color(0xFFF1F5F9); // fondo circular gris claro
}

class _TransicionWebSafari extends PageTransitionsBuilder {
  const _TransicionWebSafari();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 160);

  @override
  Duration get reverseTransitionDuration => Duration.zero;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(opacity: animation, child: child);
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: CEColors.primary,
        primary: CEColors.primary,
        secondary: CEColors.accent,
        surface: CEColors.surface,
        error: CEColors.danger,
      ),
      scaffoldBackgroundColor: CEColors.surface,
      textTheme: GoogleFonts.interTextTheme(),
    );

    return base.copyWith(
      // En Safari (iPhone/iPad/Mac) el gesto de "atras" ya trae su propia
      // animacion del navegador; si Flutter ademas anima la salida de la
      // pantalla, se ve doble (la pantalla vuelve a aparecer y se va
      // deslizando) y parece que la pagina se recarga. Solo web.
      pageTransitionsTheme: kIsWeb
          ? const PageTransitionsTheme(builders: {
              TargetPlatform.iOS: _TransicionWebSafari(),
              TargetPlatform.macOS: _TransicionWebSafari(),
            })
          : const PageTransitionsTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: CEColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: CEColors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: CEColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: CEColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: CEColors.accent, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: CEColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
