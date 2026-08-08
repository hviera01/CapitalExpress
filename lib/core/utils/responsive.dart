import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

/// A partir de este ancho se considera "escritorio" (web ancho, Windows).
const double kAnchoEscritorio = 900;

bool esEscritorio(BuildContext context) => MediaQuery.sizeOf(context).width >= kAnchoEscritorio;

/// Solo Web en una ventana ancha (navegador de escritorio) -- a
/// diferencia de [esEscritorio], NO incluye la app nativa de Windows
/// (esa sigue con su propio rail lateral, sin tocar). El menu superior
/// fijo (CeTopNav) y las tablas de datos son exclusivos de este caso.
bool esEscritorioWeb(BuildContext context) => kIsWeb && esEscritorio(context);
