import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
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

/// Para RECIBOS (abono/prestamo) en Android especificamente: en vez de
/// la vista previa -- ahi el boton "Imprimir" manda al dialogo de
/// impresion NATIVO de Android, donde RawBT no aparece como opcion,
/// confirmado probando en un equipo real -- se abre DIRECTO el panel
/// de compartir de Android (Intent.ACTION_SEND, mismo mecanismo que
/// compartirReciboPDF en el sistema viejo), que es donde SI aparece
/// RawBT como destino para imprimir por Bluetooth. Asi el cobrador no
/// tiene que entrar a la vista previa y tocar "Compartir" a mano cada
/// vez. En cualquier otra plataforma (Web, Windows) se mantiene la
/// vista previa normal, con imprimir/compartir/descargar.
Future<void> mostrarOCompartirRecibo(
  BuildContext context, {
  required String titulo,
  required Future<Uint8List> Function() generar,
  String nombreArchivo = 'recibo.pdf',
}) async {
  if (!kIsWeb && Platform.isAndroid) {
    final bytes = await generar();
    await Printing.sharePdf(bytes: bytes, filename: nombreArchivo);
    return;
  }
  await abrirVistaPreviaPdf(context, titulo: titulo, generar: generar, nombreArchivo: nombreArchivo);
}
