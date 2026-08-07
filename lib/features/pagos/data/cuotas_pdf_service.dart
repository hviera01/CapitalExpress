import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/cuotas_calculos.dart';

const _navy = PdfColor.fromInt(0xFF0A192F);
const _accent = PdfColor.fromInt(0xFF007AFF);
const _success = PdfColor.fromInt(0xFF16A34A);
const _danger = PdfColor.fromInt(0xFFDC2626);
const _surface = PdfColor.fromInt(0xFFF8FAFC);
const _border = PdfColor.fromInt(0xFFE2E8F0);
const _textSecondary = PdfColor.fromInt(0xFF64748B);

class CuotasPdfService {
  static Future<Uint8List> generar({
    required String cliente,
    required String numeroPrestamo,
    required List<CuotaInfo> cuotas,
    required double mora,
  }) async {
    final pdf = pw.Document();
    final completadas = cuotas.where((c) => c.estado == EstadoCuota.pagada).length;
    final parciales = cuotas.where((c) => c.estado == EstadoCuota.parcial).length;
    final pendientes = cuotas.where((c) => c.estado == EstadoCuota.pendiente).length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 36),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Página ${context.pageNumber} de ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 9, color: _textSecondary)),
        ),
        build: (context) => [
          pw.Text('Cuotas del Préstamo',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _navy)),
          pw.SizedBox(height: 4),
          pw.Text('$cliente · N° $numeroPrestamo', style: pw.TextStyle(fontSize: 10, color: _textSecondary)),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(color: _navy, borderRadius: pw.BorderRadius.circular(10)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _stat('Completadas', '$completadas'),
                _stat('Parciales', '$parciales'),
                _stat('Pendientes', '$pendientes'),
                if (mora > 0) _stat('Mora', formatearLempiras(mora)),
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
                  _th('Cuota'),
                  _th('Vencimiento'),
                  _th('Esperado'),
                  _th('Pagado'),
                  _th('Estado'),
                ],
              ),
              for (var i = 0; i < cuotas.length; i++)
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : _surface),
                  children: [
                    _td('#${cuotas[i].numero}'),
                    _td(_f(cuotas[i].fechaVencimiento)),
                    _td(formatearLempiras(cuotas[i].montoEsperado)),
                    _td(formatearLempiras(cuotas[i].montoPagado)),
                    _td(
                      cuotas[i].estado == EstadoCuota.pagada
                          ? 'Pagada'
                          : cuotas[i].estado == EstadoCuota.parcial
                              ? 'Parcial'
                              : 'Pendiente',
                      color: cuotas[i].estado == EstadoCuota.pagada
                          ? _success
                          : cuotas[i].estado == EstadoCuota.parcial
                              ? _accent
                              : _danger,
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static String _f(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

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
        child: pw.Text(texto,
            style: pw.TextStyle(fontSize: 9, color: color ?? PdfColors.black, fontWeight: color != null ? pw.FontWeight.bold : null)),
      );
}
