import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

int _contador = 0;

/// Visor de PDF embebido en la pagina, en vez de una pestaña nueva:
/// el visor NATIVO del navegador (el mismo que usa cuando abris un PDF
/// directo), montado como un <iframe> apuntando a un blob local -- no
/// depende de pdf.js (que se quedaba "cargando" para siempre en varios
/// navegadores/redes sin ningun error visible).
Widget construirVisorPdfEmbebido(Uint8List bytes) {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: 'application/pdf'));
  final url = web.URL.createObjectURL(blob);
  final viewType = 'ce-pdf-embed-${_contador++}';

  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    return web.HTMLIFrameElement()
      ..src = url
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%';
  });

  return HtmlElementView(viewType: viewType);
}
