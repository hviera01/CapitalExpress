// Windows/Android compilan la implementacion vacia (package:web no
// existe fuera de web); solo el build web compila la real.
export 'pdf_embed_stub.dart' if (dart.library.js_interop) 'pdf_embed_web.dart';
