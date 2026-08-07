import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/currency_utils.dart';

const _navy = PdfColor.fromInt(0xFF0A192F);
const _accent = PdfColor.fromInt(0xFF007AFF);
const _surface = PdfColor.fromInt(0xFFF8FAFC);
const _border = PdfColor.fromInt(0xFFE2E8F0);
const _textSecondary = PdfColor.fromInt(0xFF64748B);

class FilaReportePrestamo {
  final String cliente;
  final String numeroPrestamo;
  final String estado;
  final double monto;
  final double montoPagado;
  final double saldo;
  final String fecha;

  const FilaReportePrestamo({
    required this.cliente,
    required this.numeroPrestamo,
    required this.estado,
    required this.monto,
    required this.montoPagado,
    required this.saldo,
    required this.fecha,
  });
}

class ReportePrestamosPdfService {
  static Future<Uint8List> generar({
    required List<FilaReportePrestamo> filas,
    required String filtroTexto,
  }) async {
    final pdf = pw.Document();
    final activos = filas.where((f) => f.estado != 'saldado').length;
    final montoPrestado = filas.fold<double>(0, (a, f) => a + f.monto);
    final montoPagado = filas.fold<double>(0, (a, f) => a + f.montoPagado);
    final pendiente = filas.fold<double>(0, (a, f) => a + f.saldo);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 36),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Página ${context.pageNumber} de ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 9, color: _textSecondary)),
        ),
        build: (context) => [
          pw.Text('Reporte de Préstamos',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _navy)),
          pw.SizedBox(height: 4),
          pw.Text(filtroTexto, style: pw.TextStyle(fontSize: 9, color: _textSecondary)),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(color: _navy, borderRadius: pw.BorderRadius.circular(10)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _stat('Total', '${filas.length}'),
                _stat('Activos', '$activos'),
                _stat('Prestado', formatearLempiras(montoPrestado)),
                _stat('Pagado', formatearLempiras(montoPagado)),
                _stat('Pendiente', formatearLempiras(pendiente)),
              ],
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Table(
            border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _border, width: 0.5)),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _navy),
                children: [
                  _th('Cliente'),
                  _th('N° Préstamo'),
                  _th('Estado'),
                  _th('Prestado'),
                  _th('Pagado'),
                  _th('Saldo'),
                  _th('Fecha'),
                ],
              ),
              for (var i = 0; i < filas.length; i++)
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : _surface),
                  children: [
                    _td(filas[i].cliente),
                    _td(filas[i].numeroPrestamo),
                    _td(filas[i].estado),
                    _td(formatearLempiras(filas[i].monto)),
                    _td(formatearLempiras(filas[i].montoPagado)),
                    _td(formatearLempiras(filas[i].saldo), color: _accent),
                    _td(filas[i].fecha),
                  ],
                ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _stat(String label, String valor) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey300)),
          pw.SizedBox(height: 2),
          pw.Text(valor, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
        ],
      );

  static pw.Widget _th(String texto) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: pw.Text(texto,
            style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9)),
      );

  static pw.Widget _td(String texto, {PdfColor? color}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        child: pw.Text(texto, style: pw.TextStyle(fontSize: 9, color: color ?? PdfColors.black)),
      );
}
