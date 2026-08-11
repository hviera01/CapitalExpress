import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/reporte_clientes_calculos.dart';

const _navy = PdfColor.fromInt(0xFF0A192F);
const _accent = PdfColor.fromInt(0xFF007AFF);
const _surface = PdfColor.fromInt(0xFFF8FAFC);
const _border = PdfColor.fromInt(0xFFE2E8F0);
const _textSecondary = PdfColor.fromInt(0xFF64748B);

class FilaReporteCliente {
  final String cliente;
  final String telefono;
  final String cobrador;
  final String estado;
  final TotalesCliente totales;
  final DateTime? proximoPago;

  const FilaReporteCliente({
    required this.cliente,
    required this.telefono,
    required this.cobrador,
    required this.estado,
    required this.totales,
    required this.proximoPago,
  });
}

class ReporteClientesPdfService {
  static Future<Uint8List> generar({
    required List<FilaReporteCliente> filas,
    required String filtroEstadoTexto,
    required String filtroCobradorTexto,
  }) async {
    final pdf = pw.Document();
    final logoBytes = await rootBundle.load('assets/images/logo_sieg_icono.png');
    final logo = pw.MemoryImage(logoBytes.buffer.asUint8List());

    final totalClientes = filas.length;
    final activos = filas.where((f) => f.estado == 'activo').length;
    final saldados = filas.where((f) => f.estado == 'saldado').length;
    final prestado = filas.fold<double>(0, (a, f) => a + f.totales.prestado);
    final abonado = filas.fold<double>(0, (a, f) => a + f.totales.abonado);
    final mora = filas.fold<double>(0, (a, f) => a + f.totales.mora);
    final pendiente = filas.fold<double>(0, (a, f) => a + f.totales.pendiente);
    final generadoEl = DateTime.now();
    final formatoFecha = '${generadoEl.day.toString().padLeft(2, '0')}/'
        '${generadoEl.month.toString().padLeft(2, '0')}/${generadoEl.year} '
        '${generadoEl.hour.toString().padLeft(2, '0')}:${generadoEl.minute.toString().padLeft(2, '0')}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 36),
        header: (context) {
          if (context.pageNumber > 1) {
            return pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: _border)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Reporte de Clientes',
                      style: pw.TextStyle(fontSize: 10, color: _textSecondary)),
                  pw.Text('SIEG S. de R.L. de C.V.',
                      style: pw.TextStyle(fontSize: 10, color: _textSecondary)),
                ],
              ),
            );
          }
          return pw.SizedBox();
        },
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 9, color: _textSecondary),
          ),
        ),
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Image(logo, height: 40),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Reporte de Clientes',
                        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _navy)),
                    pw.SizedBox(height: 2),
                    pw.Text('Generado el $formatoFecha  ·  Estado: $filtroEstadoTexto  ·  Cobrador: $filtroCobradorTexto',
                        style: pw.TextStyle(fontSize: 9, color: _textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(color: _navy, borderRadius: pw.BorderRadius.circular(10)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Resumen',
                    style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 12)),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _statChip('Clientes', '$totalClientes'),
                    _statChip('Activos', '$activos'),
                    _statChip('Saldados', '$saldados'),
                    _statChip('Prestado', formatearLempiras(prestado)),
                    _statChip('Abonado', formatearLempiras(abonado)),
                    _statChip('Pendiente sin mora',
                        formatearLempiras((pendiente - mora).clamp(0, double.infinity))),
                    _statChip('Mora', formatearLempiras(mora)),
                    _statChip('Pendiente con mora', formatearLempiras(pendiente)),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Table(
            border: const pw.TableBorder(
              horizontalInside: pw.BorderSide(color: _border, width: 0.5),
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(2.0),
              1: pw.FlexColumnWidth(1.2),
              2: pw.FlexColumnWidth(1.6),
              3: pw.FlexColumnWidth(1.0),
              4: pw.FlexColumnWidth(1.2),
              5: pw.FlexColumnWidth(1.2),
              6: pw.FlexColumnWidth(1.0),
              7: pw.FlexColumnWidth(1.3),
              8: pw.FlexColumnWidth(1.3),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _navy),
                children: [
                  _th('Cliente'),
                  _th('Teléfono'),
                  _th('Cobrador'),
                  _th('Estado'),
                  _th('Prestado'),
                  _th('Abonado'),
                  _th('Mora'),
                  _th('Pendiente'),
                  _th('Próximo pago'),
                ],
              ),
              for (var i = 0; i < filas.length; i++)
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: i.isEven ? PdfColors.white : _surface),
                  children: [
                    _td(filas[i].cliente),
                    _td(filas[i].telefono.isEmpty ? 'N/D' : filas[i].telefono),
                    _td(filas[i].cobrador),
                    _td(filas[i].estado[0].toUpperCase() + filas[i].estado.substring(1)),
                    _td(formatearLempiras(filas[i].totales.prestado)),
                    _td(formatearLempiras(filas[i].totales.abonado)),
                    _td(filas[i].totales.mora > 0 ? formatearLempiras(filas[i].totales.mora) : '—'),
                    _td(formatearLempiras(filas[i].totales.pendiente), color: _accent),
                    _td(filas[i].proximoPago == null
                        ? '—'
                        : '${filas[i].proximoPago!.day.toString().padLeft(2, '0')}/${filas[i].proximoPago!.month.toString().padLeft(2, '0')}/${filas[i].proximoPago!.year}'),
                  ],
                ),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _statChip(String label, String valor) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey300)),
        pw.SizedBox(height: 2),
        pw.Text(valor, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
      ],
    );
  }

  static pw.Widget _th(String texto) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: pw.Text(texto,
            style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9)),
      );

  static pw.Widget _td(String texto, {PdfColor? color}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        child: pw.Text(texto,
            style: pw.TextStyle(fontSize: 9, color: color ?? PdfColors.black),
            overflow: pw.TextOverflow.clip),
      );
}
