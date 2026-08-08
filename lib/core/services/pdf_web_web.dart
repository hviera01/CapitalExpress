import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Abre una pestaña nueva EN BLANCO de inmediato (sincronico, sin
/// await de por medio) para que el navegador no la bloquee como
/// popup -- recien despues se le carga el PDF ya generado (ver
/// escribirPdfEnPestana). Si se esperara a tener los bytes ANTES de
/// abrir la pestana, el navegador la bloquearia por no estar ya
/// asociada al gesto del usuario (mismo motivo por el que el dialogo
/// de impresion se rompia si se llamaba despues de un await).
web.Window? abrirPdfEnPestanaWeb() => web.window.open('', '_blank');

void escribirPdfEnPestana(web.Window? ventana, Uint8List bytes) {
  if (ventana == null) return;
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/pdf'),
  );
  final url = web.URL.createObjectURL(blob);
  ventana.location.href = url;
}

void cerrarPestana(web.Window? ventana) => ventana?.close();
