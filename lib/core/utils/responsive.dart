import 'package:flutter/widgets.dart';

/// A partir de este ancho se considera "escritorio" (web ancho, Windows).
const double kAnchoEscritorio = 900;

bool esEscritorio(BuildContext context) => MediaQuery.sizeOf(context).width >= kAnchoEscritorio;
