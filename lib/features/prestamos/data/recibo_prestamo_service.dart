import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/models/prestamo_model.dart';
import '../../../core/utils/currency_utils.dart';

/// Recibo de desembolso del préstamo, equivalente a
/// ReciboHelper.generarReciboPrestamoPDF (Kotlin) — formato angosto tipo
/// ticket termico (80mm) para que sirva tanto para imprimir en una
/// impresora de recibos como para PDF normal en pantalla.
class ReciboPrestamoService {
  static Future<void> imprimir(PrestamoModel p) async {
    final pdf = pw.Document();
    final fecha = p.fecha?.toDate();
    final proximo = p.proximoPago;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 12),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text('CAPITAL EXPRESS',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Center(child: pw.Text('=' * 32, style: const pw.TextStyle(fontSize: 10))),
            pw.SizedBox(height: 8),
            pw.Text('RECIBO DE PRÉSTAMO', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            _fila('Préstamo N°', p.numeroPrestamo),
            _fila('Cliente', p.cliente),
            if (fecha != null) _fila('Fecha', '${fecha.day}/${fecha.month}/${fecha.year}'),
            _fila('Lugar', p.lugar),
            pw.Divider(),
            _fila('Monto prestado', formatearLempiras(p.monto)),
            _fila('Interés', formatearLempiras(p.interes)),
            _fila('Total a pagar', formatearLempiras(p.totalPagar)),
            _fila('Cuotas', '${p.cuotas} (${p.plazo})'),
            _fila('Monto cuota', formatearLempiras(p.cuota)),
            if (proximo is Timestamp) ...[
              () {
                final d = proximo.toDate();
                return _fila('Próximo pago', '${d.day}/${d.month}/${d.year}');
              }(),
            ],
            pw.Divider(),
            _fila('Cobrador', p.cobrador.isEmpty ? 'Sin asignar' : p.cobrador),
            pw.SizedBox(height: 10),
            pw.Center(child: pw.Text('=' * 32, style: const pw.TextStyle(fontSize: 10))),
            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.Text('Gracias por su preferencia',
                  style: const pw.TextStyle(fontSize: 9)),
            ),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static pw.Widget _fila(String label, String valor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.Text(valor,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}
