// Windows/Android compilan la implementacion vacia (dart:js_interop no
// existe fuera de web); solo el build web compila la real, ver
// window.limpiarCacheYRecargarApp en web/index.html.
export 'web_refresh_stub.dart' if (dart.library.js_interop) 'web_refresh_web.dart';
