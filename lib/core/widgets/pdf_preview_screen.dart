import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

/// Vista previa de un PDF en pantalla, con imprimir/compartir incluidos
/// (el paquete `printing` ya trae esos botones en `PdfPreview`). El
/// sistema Kotlin original NO tenia esto -- ahi "vista previa" era solo
/// un resumen de texto antes de generar el archivo; esto es una mejora
/// real sobre el original, pedida explicitamente.
class PdfPreviewScreen extends StatelessWidget {
  final String titulo;
  final Future<Uint8List> Function() generar;
  final String nombreArchivo;

  const PdfPreviewScreen({
    super.key,
    required this.titulo,
    required this.generar,
    this.nombreArchivo = 'reporte.pdf',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: PdfPreview(
        build: (format) => generar(),
        pdfFileName: nombreArchivo,
        canChangePageFormat: false,
        canChangeOrientation: false,
      ),
    );
  }
}

/// Abre la vista previa en una pantalla nueva. Devuelve el Future del
/// push (se completa cuando el usuario vuelve/cierra la vista previa)
/// para que quien la abre pueda encadenar algo despues -- ej. el
/// dialogo de "¿Necesita otra copia?" al terminar de registrar un
/// abono, igual que RegistrarPagoScreen.kt.
Future<void> abrirVistaPreviaPdf(
  BuildContext context, {
  required String titulo,
  required Future<Uint8List> Function() generar,
  String nombreArchivo = 'reporte.pdf',
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => PdfPreviewScreen(
        titulo: titulo,
        generar: generar,
        nombreArchivo: nombreArchivo,
      ),
    ),
  );
}
