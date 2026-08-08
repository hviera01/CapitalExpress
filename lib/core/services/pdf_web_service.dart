// Windows/Android compilan la implementacion vacia (package:web no
// existe fuera de web); solo el build web compila la real.
export 'pdf_web_stub.dart' if (dart.library.js_interop) 'pdf_web_web.dart';
