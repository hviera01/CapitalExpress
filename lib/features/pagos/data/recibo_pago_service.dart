import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/models/pago_model.dart';
import '../../../core/models/prestamo_model.dart';
import '../../../core/utils/cuotas_calculos.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/widgets/pdf_preview_screen.dart';

String _f2(int n) => n.toString().padLeft(2, '0');
String _fecha(DateTime d) => '${_f2(d.day)}/${_f2(d.month)}/${d.year}';
String _fechaHora(DateTime d) => '${_fecha(d)} ${_f2(d.hour)}:${_f2(d.minute)}';

/// Recibo de abono (reimprimir), mismo contenido y orden que
/// ReciboHelper.generarReciboPDF en el sistema viejo (ticket termico
/// 80mm): lugar, prestamo, fechas de inicio/cancelacion proyectada,
/// cliente, abono, desglose cuota/mora, saldo anterior/nuevo, proxima
/// fecha, cobrador -- para que el recibo reimpreso sea igual al que
/// salio impreso quando se registro el pago originalmente.
class ReciboPagoService {
  /// Abre una vista previa del recibo en una pantalla nueva, con
  /// imprimir/compartir/descargar ya incluidos (mismo widget que usan
  /// los reportes). Esto evita por completo el problema de navegadores
  /// que bloquean en silencio un dialogo de impresion disparado despues
  /// de un `await` -- ahora el unico gesto directo del usuario es
  /// "entrar a ver el recibo", y el boton de imprimir vive DENTRO de esa
  /// pantalla, se preciona aparte y ahi si es un click directo.
  static void mostrarVistaPrevia(BuildContext context, PagoModel p) {
    abrirVistaPreviaPdf(
      context,
      titulo: 'Recibo de Abono',
      nombreArchivo: 'recibo_abono_${p.numeroPrestamo}.pdf',
      generar: () => _generar(p),
    );
  }

  static Future<Uint8List> _generar(PagoModel p) async {
    PrestamoModel? prestamo;
    if (p.prestamoId.isNotEmpty) {
      final doc =
          await FirebaseFirestore.instance.collection('prestamos').doc(p.prestamoId).get();
      if (doc.exists) prestamo = PrestamoModel.fromDoc(doc);
    }

    final fecha = p.fechaPago?.toDate() ?? DateTime.now();
    final proximo = p.proximaFechaProgramada?.toDate();
    final montoPagado = p.total;
    // Igual formula que obtenerDatosReciboPago en el sistema viejo: el
    // saldo de ANTES de este pago se reconstruye sumando lo que ya se
    // resto (saldoRestante + lo que se pago ahora).
    final saldoAnterior = (p.saldoRestante ?? 0) + montoPagado;
    final saldoAntesDeMora = (saldoAnterior - p.mora).clamp(0.0, double.infinity);
    final nuevoSaldo = p.saldoRestante ?? (saldoAnterior - montoPagado).clamp(0.0, double.infinity);

    String? fechaInicioTexto;
    String? fechaCancelacionTexto;
    int? cuotasTotales;
    if (prestamo != null) {
      cuotasTotales = prestamo.cuotas;
      final inicio = prestamo.fecha?.toDate();
      if (inicio != null) {
        fechaInicioTexto = _fecha(inicio);
        if (prestamo.cuotas > 0) {
          fechaCancelacionTexto = _fecha(calcularFechaCuota(inicio, prestamo.plazo, prestamo.cuotas));
        }
      }
    }

    final cuotaMostrar = (p.descripcionCuotas.isNotEmpty && cuotasTotales != null && cuotasTotales > 0)
        ? '${p.descripcionCuotas} de $cuotasTotales'
        : p.descripcionCuotas;

    final ahora = DateTime.now();

    final pdf = pw.Document();
    pdf.addPage(
      // Mismas medidas EXACTAS que ReciboHelper.generarReciboPDF en el
      // sistema viejo: 189x612pt (no son "80mm genericos" -- son los
      // valores afinados a mano contra la impresora termica real, ver
      // comentarios de ese archivo sobre por que se recorto de 756 a
      // 612 y por que el margen superior subio a 32f).
      pw.Page(
        pageFormat: const PdfPageFormat(189, 612, marginAll: 15),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(
              child: pw.Text('CAPITAL EXPRESS',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Center(child: pw.Text('FINANCIERA', style: const pw.TextStyle(fontSize: 8))),
            pw.SizedBox(height: 4),
            pw.Center(child: pw.Text('[ COPIA ]', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 1),
            if (p.lugar.isNotEmpty)
              pw.Center(child: pw.Text(p.lugar, style: const pw.TextStyle(fontSize: 8))),
            pw.Center(
                child: pw.Text('Prestamo N° ${p.numeroPrestamo}', style: const pw.TextStyle(fontSize: 8))),
            if (fechaInicioTexto != null)
              pw.Center(child: pw.Text('Inicio: $fechaInicioTexto', style: const pw.TextStyle(fontSize: 8))),
            if (fechaCancelacionTexto != null)
              pw.Center(
                  child: pw.Text('Cancelación prog.: $fechaCancelacionTexto',
                      style: const pw.TextStyle(fontSize: 8))),
            pw.Center(
                child: pw.Text('Doc ${_fechaHora(fecha).replaceAll('/', '')}',
                    style: const pw.TextStyle(fontSize: 8))),
            pw.SizedBox(height: 6),
            pw.Center(
                child: pw.Text('Sr(a) ${p.clienteNombre.toUpperCase()}',
                    style: const pw.TextStyle(fontSize: 8))),
            pw.SizedBox(height: 8),
            pw.Center(child: pw.Text('Abono', style: const pw.TextStyle(fontSize: 8))),
            pw.SizedBox(height: 2),
            pw.Center(
                child: pw.Text(formatearLempiras(montoPagado),
                    style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 6),
            if (cuotaMostrar.isNotEmpty)
              pw.Center(child: pw.Text(cuotaMostrar, style: const pw.TextStyle(fontSize: 8))),
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 1),
            if (cuotaMostrar.isNotEmpty) ...[
              pw.Text('Cuotas:', style: const pw.TextStyle(fontSize: 7)),
              pw.Text(cuotaMostrar, style: const pw.TextStyle(fontSize: 7)),
            ],
            _fila('Fecha', _fechaHora(fecha)),
            _fila('Saldo anterior', formatearLempiras(saldoAntesDeMora)),
            if (p.mora > 0) ...[
              _fila('Mora aplicada', formatearLempiras(p.mora)),
              _fila('Saldo con mora', formatearLempiras(saldoAnterior)),
            ],
            _fila('Abono', formatearLempiras(montoPagado)),
            _fila('Aplicado a cuota', formatearLempiras(p.monto)),
            _fila('Aplicado a mora', formatearLempiras(p.mora)),
            if (p.mora > 0)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 3),
                child: pw.Text(
                  'Se tomaron ${formatearLempiras(p.monto)} para la cuota y ${formatearLempiras(p.mora)} de mora.',
                  style: const pw.TextStyle(fontSize: 7),
                ),
              ),
            pw.SizedBox(height: 5),
            pw.Divider(thickness: 1),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Saldo pendiente:',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Text(formatearLempiras(nuevoSaldo),
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              ],
            ),
            pw.SizedBox(height: 8),
            if (proximo != null) ...[
              pw.Center(child: pw.Text('Próxima fecha de pago:', style: const pw.TextStyle(fontSize: 8))),
              pw.Center(child: pw.Text(_fecha(proximo), style: const pw.TextStyle(fontSize: 8))),
              pw.SizedBox(height: 6),
            ],
            pw.Center(child: pw.Text('Cobrado por:', style: const pw.TextStyle(fontSize: 7))),
            pw.Center(
                child: pw.Text(p.nombreCobrador.isEmpty ? 'Sin asignar' : p.nombreCobrador,
                    style: const pw.TextStyle(fontSize: 7))),
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 1),
            pw.SizedBox(height: 4),
            pw.Center(child: pw.Text(_fecha(ahora), style: const pw.TextStyle(fontSize: 7))),
            pw.Center(
                child: pw.Text('${_f2(ahora.hour)}:${_f2(ahora.minute)}:${_f2(ahora.second)}',
                    style: const pw.TextStyle(fontSize: 7))),
            pw.SizedBox(height: 6),
            pw.Center(
                child: pw.Text('CONSERVE ESTE RECIBO',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
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
          pw.Text(label, style: const pw.TextStyle(fontSize: 7)),
          pw.Text(valor, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}
