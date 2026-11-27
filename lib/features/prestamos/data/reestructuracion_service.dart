import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/texto_reestructura.dart';
import 'package:intl/intl.dart';

import '../../../core/models/prestamo_model.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../core/utils/prestamo_calculos.dart';
import '../../../core/utils/reglas_credito.dart' show tasaGeneralPct;
import '../../bitacora/data/bitacora_repository.dart';
import '../../reglas_credito/data/reglas_credito_service.dart';
import 'prestamo_repository.dart';

class PropuestaReestructuracion {
  final double saldoActual;
  final double moraActual;
  final bool incluirMora;
  final double interesMensualPct;
  final int cuotas;
  final String plazo;
  final DateTime fechaInicio;

  const PropuestaReestructuracion({
    required this.saldoActual,
    required this.moraActual,
    required this.incluirMora,
    required this.interesMensualPct,
    required this.cuotas,
    required this.plazo,
    required this.fechaInicio,
  });

  double get base {
    final b = incluirMora ? saldoActual : saldoActual - moraActual;
    return b < 0 ? 0 : (b * 100).round() / 100;
  }

  int get diasEfectivos => calcularDiasEfectivos(plazo, cuotas, fechaInicio);

  ResultadoCalculoPrestamo get calculo => calcularInteresYCuota(
        monto: base,
        cuotas: cuotas,
        plazo: plazo,
        diasEfectivos: diasEfectivos,
        usarInteresMensual: true,
        interesPct: interesMensualPct,
        interesTotalFijo: 0,
      );

  bool get valida => base > 0 && cuotas > 0 && interesMensualPct >= 0;
}

class ReestructuracionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final PrestamoRepository _prestamos = PrestamoRepository();

  Future<({String id, String numero})> reestructurar({
    required PrestamoModel original,
    required PropuestaReestructuracion propuesta,
    required String motivo,
    required String usuarioUid,
    required String usuarioNombre,
  }) async {
    if (!propuesta.valida) {
      throw StateError('Revise el saldo, las cuotas y el interés.');
    }
    final fmt = DateFormat('dd/MM/yyyy');
    final motivoLimpio = motivo.trim().toUpperCase();
    final viejoRef = _db.collection('prestamos').doc(original.prestamoId);
    final nuevoRef = _db.collection('prestamos').doc();
    final clienteRef = _db.collection('clientes').doc(original.clienteId);
    final eventoRef = _db.collection('eventos_credito').doc();
    final numero = await _prestamos.generarNumeroPrestamo(original.cliente);
    final calculo = propuesta.calculo;
    final base = propuesta.base;
    final pct = propuesta.interesMensualPct;
    final numeroViejo = original.numeroPrestamo.isEmpty ? original.prestamoId : original.numeroPrestamo;
    final hoy = DateTime.now();

    await _db.runTransaction((tx) async {
      final snap = await tx.get(viejoRef);
      final d = snap.data();
      if (d == null) throw StateError('El préstamo ya no existe.');
      final estado = (d['estado'] ?? '') as String;
      if (d['eliminado'] == true) throw StateError('El préstamo está eliminado.');
      if (estado != 'activo' && estado != 'mora') {
        throw StateError('Solo se puede ${TxtR.verbo} un préstamo activo o en mora (este está "$estado").');
      }
      final saldo = (d['saldo'] as num?)?.toDouble() ?? 0;
      final mora = (d['mora'] as num?)?.toDouble() ?? 0;
      if ((saldo - propuesta.saldoActual).abs() > 0.01 || (mora - propuesta.moraActual).abs() > 0.01) {
        throw StateError('El saldo del préstamo cambió mientras se preparaba la ${TxtR.sust}. Vuelva a abrirla.');
      }

      final asignados = (d['cobradoresAsignados'] as List?)?.map((e) => e.toString()).toList() ??
          [if ((d['cobradorAsignado'] ?? '') != '') d['cobradorAsignado'] as String];

      tx.set(nuevoRef, {
        'id': nuevoRef.id,
        'prestamoId': nuevoRef.id,
        'numeroPrestamo': numero,
        'cliente': original.cliente,
        'clienteId': original.clienteId,
        'monto': base,
        'interes': calculo.interesCalculado,
        'interesMensual': pct,
        'tipoTasa': pct < tasaGeneralPct ? 'preferencial' : 'general',
        'interesTotal': calculo.interesCalculado,
        'usarInteresMensual': true,
        'interesTotalFijo': 0.0,
        'mora': 0.0,
        'totalPagar': calculo.totalAPagar,
        'cuota': calculo.cuotaEstimada,
        'cuotas': propuesta.cuotas,
        'plazo': propuesta.plazo,
        'fecha': Timestamp.fromDate(propuesta.fechaInicio),
        'lugar': d['lugar'] ?? '',
        'firma': '',
        'garantia': d['garantia'] ?? '',
        'observaciones': '${TxtR.sustUp} DEL PRÉSTAMO N° $numeroViejo. $motivoLimpio'.trim(),
        'cobrador': d['cobrador'] ?? '',
        'numeroCobrador': d['numeroCobrador'] ?? '',
        'cobradorUid': d['cobradorUid'] ?? '',
        'cobradorAsignado': d['cobradorAsignado'] ?? '',
        'cobradoresAsignados': asignados,
        'proximoPago': Timestamp.fromDate(calcularProximaFecha(propuesta.fechaInicio, propuesta.plazo)),
        'montoPagado': 0.0,
        'saldoAnterior': base,
        'estado': 'activo',
        'fotos': d['fotos'] ?? const [],
        'diasEfectivos': propuesta.diasEfectivos,
        'saldo': calculo.totalAPagar,
        'eliminado': false,
        'fechaCreacion': FieldValue.serverTimestamp(),
        'esReestructuracion': true,
        'reestructuraDe': original.prestamoId,
        'reestructuraDeNumero': numeroViejo,
        'motivoReestructuracion': motivoLimpio,
        'fechaReestructuracion': FieldValue.serverTimestamp(),
        'reestructuradoPor': usuarioNombre,
        'saldoReestructurado': base,
        'moraIncluida': propuesta.incluirMora ? mora : 0.0,
        'moraPerdonada': propuesta.incluirMora ? 0.0 : mora,
        'cuotaAnterior': (d['cuota'] as num?)?.toDouble() ?? 0.0,
        'cuotasAnteriores': (d['cuotas'] as num?)?.toInt() ?? 0,
      });

      tx.update(viejoRef, {
        'estado': 'reestructurado',
        'saldoAlReestructurar': saldo,
        'moraAlReestructurar': mora,
        'saldo': 0.0,
        'mora': 0.0,
        'proximoPago': 'saldado',
        'reestructuradoEn': nuevoRef.id,
        'reestructuradoEnNumero': numero,
        'motivoReestructuracion': motivoLimpio,
        'fechaReestructuracion': FieldValue.serverTimestamp(),
        'reestructuradoPor': usuarioNombre,
        'fechaUltimaActualizacion': FieldValue.serverTimestamp(),
      });

      final detalle = 'Préstamo N° $numeroViejo ${TxtR.part} el ${fmt.format(hoy)} en el N° $numero '
          '(${propuesta.cuotas} cuotas de ${formatearLempiras(calculo.cuotaEstimada)}, ${propuesta.plazo.toLowerCase()}).';
      tx.update(clienteRef, {
        'reestructurado': true,
        'reestructuradoDetalle': detalle,
        'fechaReestructuracion': FieldValue.serverTimestamp(),
        'prestamosReestructurados': FieldValue.arrayUnion([original.prestamoId]),
        'incrementoElegible': false,
      });

      tx.set(eventoRef, {
        'clienteId': original.clienteId,
        'clienteNombre': original.cliente,
        'tipo': 'reestructuracion',
        'titulo': 'Préstamo N° $numeroViejo ${TxtR.partUp}: ya no se le deben dar más préstamos',
        'anterior': numeroViejo,
        'nuevo': numero,
        'motivo': [
          'No pudo pagar en tiempo y forma, pero mostró voluntad de pago; se le dio más plazo.',
          if (motivoLimpio.isNotEmpty) 'Motivo indicado: $motivoLimpio',
          'Saldo pendiente al ${TxtR.verbo}: ${formatearLempiras(saldo)}'
              '${mora > 0.01 ? ' (incluye mora de ${formatearLempiras(mora)})' : ''}.',
          if (!propuesta.incluirMora && mora > 0.01)
            'La mora de ${formatearLempiras(mora)} no se pasó al nuevo préstamo.',
          'Antes: ${original.cuotas} cuotas de ${formatearLempiras(original.cuota)} (${original.plazo.toLowerCase()}).',
          'Ahora: ${propuesta.cuotas} cuotas de ${formatearLempiras(calculo.cuotaEstimada)} '
              '(${propuesta.plazo.toLowerCase()}) al ${_pct(pct)}% mensual, en el préstamo N° $numero.',
          'Capital ${TxtR.part} ${formatearLempiras(base)} + interés nuevo '
              '${formatearLempiras(calculo.interesCalculado)} = total a pagar ${formatearLempiras(calculo.totalAPagar)}.',
          'Queda marcado como cliente ${TxtR.part}: el sistema avisará y bloqueará nuevos préstamos (solo el administrador puede autorizar una excepción).',
        ],
        'fecha': FieldValue.serverTimestamp(),
        'origen': 'reestructuracion',
        'usuario': usuarioNombre,
      });
    });

    BitacoraRepository().registrar(
      accion: 'reestructurar_prestamo',
      entidadTipo: 'prestamo',
      descripcion: 'N° $numeroViejo - ${original.cliente}: ${TxtR.part} en N° $numero '
          '(${formatearLempiras(base)}, ${propuesta.cuotas} cuotas de ${formatearLempiras(calculo.cuotaEstimada)})',
      usuarioUid: usuarioUid,
      usuarioNombre: usuarioNombre,
    );
    ReglasCreditoService().evaluarDespuesDe(original.clienteId, origen: 'reestructuracion', usuario: usuarioNombre);

    return (id: nuevoRef.id, numero: numero);
  }

  String _pct(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}
