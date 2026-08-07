import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/currency_utils.dart';

const _navy = PdfColor.fromInt(0xFF0A192F);
const _textSecondary = PdfColor.fromInt(0xFF64748B);

class DashboardPdfService {
  static Future<Uint8List> generar({
    required int totalClientes,
    required int totalCobros,
    required double totalPrestado,
    required double totalPagado,
    required double totalPendiente,
    required double totalInteres,
    required double totalMoras,
    required int cantidadMoras,
    required String filtroFechas,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Dashboard General',
                style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _navy)),
            pw.SizedBox(height: 4),
            pw.Text(filtroFechas, style: pw.TextStyle(fontSize: 10, color: _textSecondary)),
            pw.SizedBox(height: 24),
            pw.GridView(
              crossAxisCount: 2,
              childAspectRatio: 3.4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _tarjeta('Clientes', '$totalClientes'),
                _tarjeta('Cobros', '$totalCobros'),
                _tarjeta('Prestado', formatearLempiras(totalPrestado)),
                _tarjeta('Pagado', formatearLempiras(totalPagado)),
                _tarjeta('Pendiente', formatearLempiras(totalPendiente)),
                _tarjeta('Interés', formatearLempiras(totalInteres)),
                _tarjeta('Moras Cobradas', formatearLempiras(totalMoras)),
                _tarjeta('Cant. Moras', '$cantidadMoras'),
              ],
            ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  static pw.Widget _tarjeta(String label, String valor) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 10, color: _textSecondary)),
          pw.SizedBox(height: 4),
          pw.Text(valor, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _navy)),
        ],
      ),
    );
  }
}
