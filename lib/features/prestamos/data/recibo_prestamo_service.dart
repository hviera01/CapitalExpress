import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/models/cliente_model.dart';
import '../../../core/models/prestamo_model.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/firestore_parse.dart';
import '../../../core/utils/recibo_fecha_utils.dart';
import '../../../core/widgets/pdf_preview_screen.dart';

/// Recibo de desembolso del préstamo -- mismo contenido, orden y tamaño
/// EXACTOS que ReciboHelper.generarReciboPrestamoPDF en el sistema viejo:
/// ticket termico de 189x756pt (no 80mm genéricos), con los mismos
/// campos (numero de cobrador, lugar, cliente, monto grande, desglose
/// compacto, total, proximo pago, telefono/dirección del cliente,
/// firma).
class ReciboPrestamoService {
  /// En Android abre directo el panel de compartir (ahi es donde
  /// aparece RawBT para imprimir por Bluetooth); en Web/Windows abre la
  /// vista previa normal. Ver mostrarOCompartirRecibo.
  static Future<void> mostrarVistaPrevia(BuildContext context, PrestamoModel p) {
    return mostrarOCompartirRecibo(
      context,
      titulo: 'Recibo de Préstamo',
      nombreArchivo: 'recibo_prestamo_${p.numeroPrestamo}.pdf',
      generar: () => _generar(p),
    );
  }

  static Future<Uint8List> _generar(PrestamoModel p) async {
    ClienteModel? cliente;
    if (p.clienteId.isNotEmpty) {
      final doc = await FirebaseFirestore.instance.collection('clientes').doc(p.clienteId).get();
      if (doc.exists) cliente = ClienteModel.fromDoc(doc);
    }

    final fecha = p.fecha?.toDate() ?? DateTime.now();
    final proximo = asProximoPagoFecha(p.proximoPago);
    final total = p.totalPagar > 0 ? p.totalPagar : (p.monto + p.interes);
    final ahora = DateTime.now();

    final pdf = pw.Document();
    pdf.addPage(
      // Medidas EXACTAS del sistema viejo: 189x756pt (5cm x 20cm), no
      // las mismas que el recibo de abono (189x612pt) -- este recibo
      // lleva mas contenido (telefono, direccion, firma) y nunca se
      // recorto en la app original.
      pw.Page(
        pageFormat: const PdfPageFormat(189, 756, marginAll: 15),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(
              child: pw.Text('CAPITAL',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Center(
              child: pw.Text('EXPRESS',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Center(child: pw.Text('FINANCIERA', style: const pw.TextStyle(fontSize: 9))),
            pw.SizedBox(height: 4),
            if (p.numeroCobrador.isNotEmpty)
              pw.Center(child: pw.Text(p.numeroCobrador, style: const pw.TextStyle(fontSize: 9))),
            pw.SizedBox(height: 4),
            pw.Divider(thickness: 1),
            if (p.lugar.isNotEmpty)
              pw.Center(child: pw.Text(p.lugar, style: const pw.TextStyle(fontSize: 9))),
            pw.Center(
                child: pw.Text('Prestamo N° ${p.numeroPrestamo}',
                    style: const pw.TextStyle(fontSize: 9))),
            pw.Center(
                child: pw.Text('Doc ${fechaCorta(fecha).replaceAll('/', '')}',
                    style: const pw.TextStyle(fontSize: 9))),
            pw.SizedBox(height: 4),
            pw.Center(child: pw.Text('Sr(a) ${p.cliente}', style: const pw.TextStyle(fontSize: 9))),
            pw.SizedBox(height: 6),
            pw.Center(child: pw.Text('Prestamo', style: const pw.TextStyle(fontSize: 9))),
            pw.SizedBox(height: 2),
            pw.Center(
                child: pw.Text(formatearLempiras(total),
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 4),
            pw.Center(child: pw.Text('${p.cuotas} cuotas', style: const pw.TextStyle(fontSize: 9))),
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 1),
            _fila('Cuotas', '${p.cuotas}'),
            _fila('Fecha', fechaCorta(fecha)),
            _fila('Monto', formatearLempiras(p.monto)),
            _fila('Capital', formatearLempiras(p.monto)),
            _fila('Interes', formatearLempiras(p.interes)),
            if (p.mora > 0) _fila('Mora', formatearLempiras(p.mora)),
            pw.SizedBox(height: 4),
            pw.Divider(thickness: 1),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text(formatearLempiras(total),
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 8),
            if (proximo != null) ...[
              pw.Center(child: pw.Text('Proximo:', style: const pw.TextStyle(fontSize: 9))),
              pw.Center(child: pw.Text(fechaCorta(proximo), style: const pw.TextStyle(fontSize: 9))),
              pw.SizedBox(height: 4),
            ],
            if (cliente != null && cliente.telefono.isNotEmpty) ...[
              pw.Center(child: pw.Text('Tel:', style: const pw.TextStyle(fontSize: 9))),
              pw.Center(child: pw.Text(cliente.telefono, style: const pw.TextStyle(fontSize: 9))),
              pw.SizedBox(height: 4),
            ],
            if (cliente != null && cliente.direccionCasa.isNotEmpty) ...[
              pw.Center(
                  child: pw.Text(cliente.direccionCasa,
                      textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7))),
              pw.SizedBox(height: 6),
            ],
            pw.Center(child: pw.Text('Consultas llamar:', style: const pw.TextStyle(fontSize: 7))),
            if (p.numeroCobrador.isNotEmpty)
              pw.Center(child: pw.Text('(${p.numeroCobrador})', style: const pw.TextStyle(fontSize: 7))),
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 1),
            pw.SizedBox(height: 4),
            pw.Center(child: pw.Text(fechaHoraConSegundos(ahora), style: const pw.TextStyle(fontSize: 7))),
            pw.SizedBox(height: 6),
            pw.Center(
                child: pw.Text('CONSERVE ESTE RECIBO',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 8),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 20),
              child: pw.Divider(thickness: 1),
            ),
            pw.SizedBox(height: 4),
            pw.Center(child: pw.Text('Firma Cliente', style: const pw.TextStyle(fontSize: 7))),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  static pw.Widget _fila(String label, String valor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
          pw.Text(valor, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}
