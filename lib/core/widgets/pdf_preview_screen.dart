import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../services/pdf_embed_service.dart';

/// Vista previa de un PDF en pantalla. En Windows/Android usa
/// `PdfPreview` del paquete `printing` (con imprimir/compartir
/// incluidos). En Web usa un visor embebido propio (ver
/// construirVisorPdfEmbebido) en vez de `PdfPreview`: ese widget
/// renderiza con pdf.js, que depende de cargar y ejecutar bien un
/// bundle JS externo -- en la practica se quedaba "cargando" para
/// siempre en varios navegadores/redes sin ningun error visible. El
/// visor propio usa el mismo visor NATIVO del navegador (como si
/// abrieras el PDF directo), sin esa dependencia.
///
/// El sistema Kotlin original NO tenia vista previa -- ahi "vista
/// previa" era solo un resumen de texto antes de generar el archivo;
/// esto es una mejora real sobre el original, pedida explicitamente.
class PdfPreviewScreen extends StatefulWidget {
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
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  late final Future<Uint8List> _future = widget.generar();

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.titulo)),
        body: PdfPreview(
          build: (format) => widget.generar(),
          pdfFileName: widget.nombreArchivo,
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
          onError: (context, error) => _vistaError('$error'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titulo),
        actions: [
          FutureBuilder<Uint8List>(
            future: _future,
            builder: (context, snap) {
              if (!snap.hasData) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.download_outlined),
                tooltip: 'Descargar',
                onPressed: () => Printing.sharePdf(bytes: snap.data!, filename: widget.nombreArchivo),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<Uint8List>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
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
            );
          }
          if (snap.hasError) return _vistaError('${snap.error}');
          return construirVisorPdfEmbebido(snap.data!);
        },
      ),
    );
  }

  Widget _vistaError(String error) {
    return Center(
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
            Text(error, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
          ],
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
}) async {
  await Navigator.of(context).push<void>(
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
