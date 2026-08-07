import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/models/pago_model.dart';
import '../../../core/utils/currency_utils.dart';

/// Recibo de abono (reimprimir), mismo formato ticket termico (80mm)
/// que ReciboPrestamoService, para que ambos recibos se vean parejos.
class ReciboPagoService {
  static Future<void> imprimir(PagoModel p) async {
    final pdf = pw.Document();
    final fecha = p.fechaPago?.toDate();
    final proximo = p.proximaFechaProgramada?.toDate();

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
            pw.Text('RECIBO DE ABONO', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            _fila('Préstamo N°', p.numeroPrestamo),
            _fila('Cliente', p.clienteNombre),
            if (fecha != null)
              _fila('Fecha',
                  '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}  ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}'),
            if (p.descripcionCuotas.isNotEmpty) _fila('Cuota', p.descripcionCuotas),
            pw.Divider(),
            _fila('Abono', formatearLempiras(p.monto)),
            if (p.mora > 0) _fila('Mora aplicada', formatearLempiras(p.mora)),
            _fila('Total recibido', formatearLempiras(p.total)),
            if (p.saldoRestante != null)
              _fila('Saldo pendiente', formatearLempiras(p.saldoRestante!)),
            if (proximo != null)
              _fila('Próximo pago',
                  '${proximo.day.toString().padLeft(2, '0')}/${proximo.month.toString().padLeft(2, '0')}/${proximo.year}'),
            pw.Divider(),
            _fila('Método de pago', p.metodoPago),
            _fila('Cobrador', p.nombreCobrador.isEmpty ? 'Sin asignar' : p.nombreCobrador),
            if (p.lugar.isNotEmpty) _fila('Lugar', p.lugar),
            pw.SizedBox(height: 10),
            pw.Center(child: pw.Text('=' * 32, style: const pw.TextStyle(fontSize: 10))),
            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.Text('Gracias por su preferencia', style: const pw.TextStyle(fontSize: 9)),
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
          pw.Flexible(
            child: pw.Text(valor,
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
