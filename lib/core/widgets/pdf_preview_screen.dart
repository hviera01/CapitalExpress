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
        loadingWidget: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Generando recibo...'),
              ],
            ),
          ),
        ),
        // Si algo falla (generando el PDF, o el visor de PDF.js en Web),
        // antes se quedaba en blanco/cargando para siempre sin ningun
        // aviso. Esto al menos muestra el error real y deja reintentar.
        onError: (context, error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 40),
                const SizedBox(height: 12),
                const Text('No se pudo generar la vista previa',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('$error', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
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
