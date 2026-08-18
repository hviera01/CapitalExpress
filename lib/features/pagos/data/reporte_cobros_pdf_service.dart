import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/currency_utils.dart';

const _navy = PdfColor.fromInt(0xFF0A192F);
const _accent = PdfColor.fromInt(0xFF007AFF);
const _surface = PdfColor.fromInt(0xFFF8FAFC);
const _border = PdfColor.fromInt(0xFFE2E8F0);
const _textSecondary = PdfColor.fromInt(0xFF64748B);
const _success = PdfColor.fromInt(0xFF16A34A);

class FilaReporteCobro {
  final String cliente;
  final String numeroPrestamo;
  final String fechaPago;
  final double abono;
  final double mora;
  final String cobrador;

  const FilaReporteCobro({
    required this.cliente,
    required this.numeroPrestamo,
    required this.fechaPago,
    required this.abono,
    required this.mora,
    required this.cobrador,
  });
}

class FilaCobroPendiente {
  final String cliente;
  final String numeroPrestamo;
  final String urgencia;
  final String proximoPago;
  final String ultimoPago;
  final double cuota;
  final double mora;
  final String cobrador;

  const FilaCobroPendiente({
    required this.cliente,
    required this.numeroPrestamo,
    required this.urgencia,
    required this.proximoPago,
    required this.ultimoPago,
    required this.cuota,
    required this.mora,
    required this.cobrador,
  });
}

class FilaPrestamoSaldado {
  final String cliente;
  final String numeroPrestamo;
  final double prestado;
  final double abonado;
  final String fechaCreacion;

  const FilaPrestamoSaldado({
    required this.cliente,
    required this.numeroPrestamo,
    required this.prestado,
    required this.abonado,
    required this.fechaCreacion,
  });
}

class ReporteCobrosPdfService {
  static Future<Uint8List> generarPagos({
    required List<FilaReporteCobro> filas,
    required String filtroTexto,
  }) async {
    final pdf = pw.Document();
    final totalAbonos = filas.fold<double>(0, (a, f) => a + f.abono);
    final totalMora = filas.fold<double>(0, (a, f) => a + f.mora);

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
          pw.Text('Resumen de Pagos – Cobrador',
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
                _stat('Registros', '${filas.length}'),
                _stat('Abonos', formatearLempiras(totalAbonos)),
                _stat('Mora', formatearLempiras(totalMora)),
                _stat('Total Recaudado', formatearLempiras(totalAbonos + totalMora)),
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
                  _th('Fecha Pago'),
                  _th('Abono'),
                  _th('Mora'),
                  _th('Total'),
                  _th('Cobrador'),
                ],
              ),
              for (var i = 0; i < filas.length; i++)
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : _surface),
                  children: [
                    _td(filas[i].cliente),
                    _td(filas[i].numeroPrestamo),
                    _td(filas[i].fechaPago),
                    _td(formatearLempiras(filas[i].abono)),
                    _td(formatearLempiras(filas[i].mora)),
                    _td(formatearLempiras(filas[i].abono + filas[i].mora), color: _accent),
                    _td(filas[i].cobrador),
                  ],
                ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> generarPendientes({
    required List<FilaCobroPendiente> filas,
    required String filtroTexto,
  }) async {
    final pdf = pw.Document();
    final totalCuotas = filas.fold<double>(0, (a, f) => a + f.cuota);
    final totalMora = filas.fold<double>(0, (a, f) => a + f.mora);

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
          pw.Text('Cobros Pendientes',
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
                _stat('Registros', '${filas.length}'),
                _stat('Total Cuotas', formatearLempiras(totalCuotas)),
                _stat('Mora', formatearLempiras(totalMora)),
                _stat('Total a Cobrar', formatearLempiras(totalCuotas + totalMora)),
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
                  _th('Próx. Pago'),
                  _th('Último Pago'),
                  _th('Cuota'),
                  _th('Mora'),
                  _th('Cobrador'),
                ],
              ),
              for (var i = 0; i < filas.length; i++)
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : _surface),
                  children: [
                    _td(filas[i].cliente),
                    _td(filas[i].numeroPrestamo),
                    _td(filas[i].urgencia),
                    _td(filas[i].proximoPago),
                    _td(filas[i].ultimoPago),
                    _td(formatearLempiras(filas[i].cuota)),
                    _td(formatearLempiras(filas[i].mora)),
                    _td(filas[i].cobrador),
                  ],
                ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> generarSaldados({
    required List<FilaPrestamoSaldado> filas,
    required String filtroTexto,
  }) async {
    final pdf = pw.Document();

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
          pw.Text('Préstamos Saldados',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _success)),
          pw.SizedBox(height: 4),
          pw.Text(filtroTexto, style: pw.TextStyle(fontSize: 9, color: _textSecondary)),
          pw.SizedBox(height: 16),
          pw.Table(
            border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _border, width: 0.5)),
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: _success),
                children: [
                  _th('Cliente'),
                  _th('N° Préstamo'),
                  _th('Prestado'),
                  _th('Abonado'),
                  _th('F. Creación'),
                ],
              ),
              for (var i = 0; i < filas.length; i++)
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : _surface),
                  children: [
                    _td(filas[i].cliente),
                    _td(filas[i].numeroPrestamo),
                    _td(formatearLempiras(filas[i].prestado)),
                    _td(formatearLempiras(filas[i].abonado)),
                    _td(filas[i].fechaCreacion),
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
