import 'dart:js_interop';

@JS('limpiarCacheYRecargarApp')
external JSPromise<JSAny?> _limpiarCacheYRecargarApp();

Future<void> limpiarCacheYRecargarWeb() async {
  await _limpiarCacheYRecargarApp().toDart;
}
