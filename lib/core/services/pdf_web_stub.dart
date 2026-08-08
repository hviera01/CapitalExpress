import 'dart:typed_data';

/// Nunca se llama fuera de Web (ver abrirVistaPreviaPdf, que solo usa
/// esto cuando kIsWeb es true) -- existe solo para que el import
/// condicional compile en Android/Windows.
Object? abrirPdfEnPestanaWeb() => throw UnsupportedError('Solo disponible en Web');

void escribirPdfEnPestana(Object? ventana, Uint8List bytes) =>
    throw UnsupportedError('Solo disponible en Web');

void cerrarPestana(Object? ventana) => throw UnsupportedError('Solo disponible en Web');
