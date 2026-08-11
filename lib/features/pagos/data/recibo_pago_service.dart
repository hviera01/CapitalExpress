import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/models/pago_model.dart';
import '../../../core/models/prestamo_model.dart';
import '../../../core/utils/cuotas_calculos.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/recibo_fecha_utils.dart';
import '../../../core/widgets/pdf_preview_screen.dart';

/// Recibo de abono (reimprimir), mismo contenido y orden que
/// ReciboHelper.generarReciboPDF en el sistema viejo (ticket termico
/// 80mm): lugar, prestamo, fechas de inicio/cancelacion proyectada,
/// cliente, abono, desglose cuota/mora, saldo anterior/nuevo, proxima
/// fecha, cobrador -- para que el recibo reimpreso sea igual al que
/// salio impreso quando se registro el pago originalmente.
class ReciboPagoService {
  /// En Android abre directo el panel de compartir (ahi es donde
  /// aparece RawBT para imprimir por Bluetooth); en Web/Windows abre la
  /// vista previa normal con imprimir/compartir/descargar. Ver
  /// mostrarOCompartirRecibo.
  static Future<void> mostrarVistaPrevia(BuildContext context, PagoModel p) {
    return mostrarOCompartirRecibo(
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
    // Si la "proxima cuota pendiente" es la misma que quedo parcial con
    // este abono y su vencimiento ya paso (ej. cuota del dia 4, se paga
    // parcial el dia 8), no tiene sentido imprimir esa fecha vencida --
    // se muestra la proxima fecha real DESPUES de hoy, la proxima vez
    // que el cobrador pasaria.
    final proximo = p.proximaFechaProgramada != null
        ? proximaFechaVisitaDespuesDe(p.proximaFechaProgramada!.toDate(), p.plazo, fecha)
        : null;
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
        fechaInicioTexto = fechaCorta(inicio);
        if (prestamo.cuotas > 0) {
          fechaCancelacionTexto =
              fechaCorta(calcularFechaCuota(inicio, prestamo.plazo, prestamo.cuotas));
        }
      }
    }

    // La impresora termica no tiene el glifo de "✓" (sale como un
    // cuadro/caracter incompatible) -- se saca solo para el recibo
    // impreso, el check normal en pantalla no se toca.
    final descripcionCuotasPdf = p.descripcionCuotas.replaceAll(' ✓', '');
    final cuotaMostrar =
        (descripcionCuotasPdf.isNotEmpty && cuotasTotales != null && cuotasTotales > 0)
            ? '$descripcionCuotasPdf de $cuotasTotales'
            : descripcionCuotasPdf;

    final ahora = DateTime.now();

    final pdf = pw.Document();
    pdf.addPage(
      // Mismas medidas EXACTAS que ReciboHelper.generarReciboPDF en el
      // sistema viejo: 189x612pt (no son "80mm genericos" -- son los
      // valores afinados a mano contra la impresora termica real). El
      // margen superior de 32 (en vez de 15 parejo) es el mismo fix que
      // ya tenia el sistema viejo para esto -- la impresora termica
      // recorta lo primero que manda a imprimir, y con marginAll:15 se
      // perdia el nombre completo.
      pw.Page(
        pageFormat: const PdfPageFormat(189, 650,
            marginTop: 32, marginBottom: 15, marginLeft: 15, marginRight: 15),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // Nombre grande + sufijo legal chico, igual que ya funciona
            // bien en el recibo de prestamo (ver recibo_prestamo_service.dart).
            pw.Center(
              child: pw.Text('SIEG',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Center(child: pw.Text('S. DE R.L. DE C.V.', style: const pw.TextStyle(fontSize: 8))),
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
                child: pw.Text('Doc ${fechaHoraCorta(fecha).replaceAll('/', '')}',
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
            _fila('Fecha', fechaHoraCorta(fecha)),
            _fila('Saldo anterior', formatearLempiras(saldoAntesDeMora)),
            if (p.mora > 0) ...[
              _fila('Mora aplicada', formatearLempiras(p.mora)),
              _fila('Saldo con mora', formatearLempiras(saldoAnterior)),
            ],
            _fila('Abono', formatearLempiras(montoPagado)),
            // El desglose "aplicado a cuota/mora" solo tiene sentido
            // mencionarlo cuando de verdad hubo mora de por medio -- si
            // no hay mora, "Aplicado a cuota" es lo mismo que "Abono" y
            // "Aplicado a mora: L.0.00" solo genera confusion.
            if (p.mora > 0) ...[
              _fila('Aplicado a cuota', formatearLempiras(p.monto)),
              _fila('Aplicado a mora', formatearLempiras(p.mora)),
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 3),
                child: pw.Text(
                  'Se tomaron ${formatearLempiras(p.monto)} para la cuota y ${formatearLempiras(p.mora)} de mora.',
                  style: const pw.TextStyle(fontSize: 7),
                ),
              ),
            ],
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
              pw.Center(child: pw.Text(fechaCorta(proximo), style: const pw.TextStyle(fontSize: 8))),
              pw.SizedBox(height: 6),
            ],
            pw.Center(child: pw.Text('Cobrado por:', style: const pw.TextStyle(fontSize: 7))),
            pw.Center(
                child: pw.Text(p.nombreCobrador.isEmpty ? 'Sin asignar' : p.nombreCobrador,
                    style: const pw.TextStyle(fontSize: 7))),
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 1),
            pw.SizedBox(height: 4),
            pw.Center(child: pw.Text(fechaHoraConSegundos(ahora), style: const pw.TextStyle(fontSize: 7))),
            pw.SizedBox(height: 6),
            pw.Center(
                child: pw.Text('CONSERVE ESTE RECIBO',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
            // Espacio en blanco para que el cliente pueda firmar arriba
            // de la linea -- antes quedaba pegada, sin lugar para
            // firmar.
            pw.SizedBox(height: 28),
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
          pw.Text(label, style: const pw.TextStyle(fontSize: 7)),
          pw.Text(valor, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}
