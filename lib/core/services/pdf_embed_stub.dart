import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// Nunca se llama fuera de Web (ver PdfPreviewScreen, que solo usa
/// esto cuando kIsWeb es true) -- existe solo para que el import
/// condicional compile en Android/Windows.
Widget construirVisorPdfEmbebido(Uint8List bytes) =>
    throw UnsupportedError('Solo disponible en Web');
