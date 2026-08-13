import '../models/pago_model.dart';
import '../models/prestamo_model.dart';
import 'prestamo_calculos.dart';

/// Fecha de vencimiento de la cuota N (aplica calcularProximaFecha N
/// veces desde la fecha de inicio del prestamo). Igual que
/// calcularFechaCuota en el Kotlin original.
DateTime calcularFechaCuota(DateTime fechaInicio, String plazo, int numeroCuota) {
  var fecha = fechaInicio;
  for (var i = 0; i < numeroCuota; i++) {
    fecha = calcularProximaFecha(fecha, plazo);
  }
  return fecha;
}

/// Cuando la "proxima fecha de pago" a MOSTRAR (recibo, avisos) ya
/// paso -- la cuota quedo parcial y su vencimiento es anterior al dia
/// que se esta mirando -- no tiene sentido decirle al cliente/cobrador
/// que la proxima fecha es una que ya paso. Esto avanza la fecha de a
/// un plazo a la vez hasta encontrar una que caiga DESPUES de `hoy`,
/// que es la proxima vez que el cobrador realisticamente pasaria. Si
/// la fecha ya estaba en el futuro, se devuelve igual sin tocar.
DateTime proximaFechaVisitaDespuesDe(DateTime fecha, String plazo, DateTime hoy) {
  final hoySolo = DateTime(hoy.year, hoy.month, hoy.day);
  var candidato = fecha;
  var intentos = 0;
  while (!candidato.isAfter(hoySolo) && intentos < 60) {
    candidato = calcularProximaFecha(candidato, plazo);
    intentos++;
  }
  return candidato;
}

enum EstadoCuota { pagada, parcial, pendiente }

class CuotaInfo {
  final int numero;
  final DateTime fechaVencimiento;
  final double montoEsperado;
  final double montoPagado;
  final EstadoCuota estado;

  const CuotaInfo({
    required this.numero,
    required this.fechaVencimiento,
    required this.montoEsperado,
    required this.montoPagado,
    required this.estado,
  });

  double get faltante => (montoEsperado - montoPagado).clamp(0, double.infinity);
}

/// Monto que tiene que juntar la cuota `numeroCuota` para considerarse
/// completa. Todas las cuotas usan `prestamo.cuota` (el estimado
/// redondeado que se guardo al crear el prestamo) EXCEPTO LA ULTIMA,
/// que absorbe lo que sobre por el redondeo -- si no fuera asi, la
/// suma de las metas de TODAS las cuotas (cuota * cantidadDeCuotas)
/// casi nunca da exacto el total a pagar (ej. L.7,250 entre 12 cuotas
/// son L.604.166... por cuota; redondeado a L.604 cada una suman solo
/// L.7,248), y entonces por mas que el cliente pague el total completo
/// nunca terminan de "llenarse" todas las cuotas -- quedan una o dos
/// colgadas en parcial para siempre aunque el prestamo ya este
/// saldado. Con esto, pagar el total a pagar SIEMPRE completa las
/// cuotas 1..N sin dejar sobrante suelto.
double montoObjetivoCuota(PrestamoModel prestamo, int numeroCuota) {
  if (prestamo.cuotas <= 1) return prestamo.totalPagar > 0 ? prestamo.totalPagar : prestamo.cuota;
  if (numeroCuota < prestamo.cuotas) return prestamo.cuota;
  final totalPagar = prestamo.totalPagar > 0 ? prestamo.totalPagar : prestamo.monto + prestamo.interes;
  final metaSinUltima = prestamo.cuota * (prestamo.cuotas - 1);
  final ultima = totalPagar - metaSinUltima;
  // Si por algun motivo el total guardado quedo menor a lo que ya
  // suman las demas cuotas (dato viejo/editado a mano), no tiene
  // sentido pedirle una meta negativa a la ultima -- se cae al mismo
  // monto de las demas.
  return ultima > 0.01 ? ultima : prestamo.cuota;
}

/// Reconstruye cuanto se pago de cada cuota (1..cuotasTotales) sumando
/// `cuotasCubiertas` de todos los pagos del prestamo (un pago puede
/// repartirse entre varias cuotas por la cascada). La cuota 0 dentro de
/// `cuotasCubiertas` seria mora, pero esa entrada nunca se persiste en
/// el documento real (ver escribirPago), asi que en la practica esto
/// solo ve numeroCuota >= 1 de todas formas.
Map<int, double> reconstruirMontosPorCuota(List<PagoModel> pagos) {
  final montos = <int, double>{};
  for (final pago in pagos) {
    for (final c in pago.cuotasCubiertas) {
      if (c.numeroCuota <= 0) continue;
      montos[c.numeroCuota] = (montos[c.numeroCuota] ?? 0) + c.montoAplicado;
    }
  }
  return montos;
}

/// Tabla completa de cuotas de un prestamo (para Ver Cuotas), con lo que
/// se pago de cada una reconstruido desde los pagos reales.
List<CuotaInfo> construirTablaCuotas(PrestamoModel prestamo, List<PagoModel> pagos) {
  final montosPorCuota = reconstruirMontosPorCuota(pagos);
  final fechaInicio = prestamo.fecha?.toDate();
  final cuotas = <CuotaInfo>[];

  for (var n = 1; n <= prestamo.cuotas; n++) {
    final pagado = montosPorCuota[n] ?? 0.0;
    final esperado = montoObjetivoCuota(prestamo, n);
    final estado = pagado >= esperado - 0.01
        ? EstadoCuota.pagada
        : pagado > 0.01
            ? EstadoCuota.parcial
            : EstadoCuota.pendiente;
    cuotas.add(CuotaInfo(
      numero: n,
      fechaVencimiento:
          fechaInicio != null ? calcularFechaCuota(fechaInicio, prestamo.plazo, n) : DateTime.now(),
      montoEsperado: esperado,
      montoPagado: pagado,
      estado: estado,
    ));
  }
  return cuotas;
}

/// Resultado puro (no toca Firestore) de repartir un abono entre mora y
/// cuotas -- mismo algoritmo que distribuirPagoConMoraYCascada en
/// RegistrarPagoScreen.kt linea 228, portado literal:
/// 1) el abono paga primero la mora pendiente (mora ACUMULADA HISTORICA
///    del prestamo, campo `mora`, menos la mora ya cobrada en pagos
///    anteriores -- OJO: `mora` en el doc del prestamo es un total
///    historico de mora ALGUNA VEZ aplicada, no "lo que falta", eso se
///    deriva restando lo ya pagado),
/// 2) el resto se reparte en cascada entre las cuotas en orden, llenando
///    cada una hasta `cuota.montoEsperado` antes de pasar a la
///    siguiente -- si el cliente da menos de una cuota, esa cuota queda
///    parcial; si da mas, se completa y el resto pasa a la cuota
///    siguiente; si sobra despues de la ultima cuota, ese sobrante
///    igual cuenta como "pagado" (ver montoPagoNormal) aunque no quede
///    atado a ninguna cuota puntual -- asi nunca se "pierde" plata
///    aunque sea un pago raro/mal calculado.
class ResultadoDistribucion {
  final List<CuotaCubierta> cuotasCubiertas; // incluye la entrada 0 (mora) si aplica; se filtra al escribir
  final double moraAplicada;
  final double montoPagoNormal; // = montoPagado - moraAplicada (el pagos.monto real)
  final int? proximaCuotaPendiente; // null = con este pago el prestamo queda saldado
  final DateTime? fechaProximoPago; // null si proximaCuotaPendiente es null
  final int totalCuotasCompletas;
  final double moraHistoricaCorregida; // por si hubo que autocorregir el campo `mora` del prestamo

  const ResultadoDistribucion({
    required this.cuotasCubiertas,
    required this.moraAplicada,
    required this.montoPagoNormal,
    required this.proximaCuotaPendiente,
    required this.fechaProximoPago,
    required this.totalCuotasCompletas,
    required this.moraHistoricaCorregida,
  });
}

ResultadoDistribucion distribuirPagoConMoraYCascada({
  required PrestamoModel prestamo,
  required List<PagoModel> pagosPrevios,
  required double montoPagado,
}) {
  final moraPagadaAcumulada = pagosPrevios.fold<double>(0, (a, p) => a + p.mora);

  // Auto-correccion: si en algun momento se sobreescribio `mora` en vez
  // de acumularla, esto puede quedar mas chico que lo ya cobrado.
  var moraHistorica = prestamo.mora;
  if (moraHistorica > 0 && moraHistorica < moraPagadaAcumulada) {
    moraHistorica = moraPagadaAcumulada + moraHistorica;
  }
  final moraPendiente = (moraHistorica - moraPagadaAcumulada).clamp(0.0, double.infinity);

  var restante = montoPagado;
  final cuotasCubiertas = <CuotaCubierta>[];
  var moraAplicada = 0.0;

  if (moraPendiente > 0.01 && restante > 0.01) {
    moraAplicada = restante < moraPendiente ? restante : moraPendiente;
    final moraCompleta = moraAplicada >= moraPendiente - 0.01;
    cuotasCubiertas.add(CuotaCubierta(
      numeroCuota: 0,
      montoAplicado: moraAplicada,
      completada: moraCompleta,
    ));
    restante -= moraAplicada;
  }

  final montoPagoNormal = montoPagado - moraAplicada;
  final montosPorCuota = reconstruirMontosPorCuota(pagosPrevios);
  var totalCuotasCompletas = 0;

  if (restante > 0.01) {
    for (var n = 1; n <= prestamo.cuotas && restante > 0.01; n++) {
      final objetivo = montoObjetivoCuota(prestamo, n);
      final yaPagado = montosPorCuota[n] ?? 0.0;
      final falta = (objetivo - yaPagado).clamp(0.0, double.infinity);
      if (falta <= 0.01) continue;
      final aplicado = restante < falta ? restante : falta;
      final totalCuota = yaPagado + aplicado;
      final completa = totalCuota >= objetivo - 0.01;
      cuotasCubiertas.add(CuotaCubierta(
        numeroCuota: n,
        montoAplicado: aplicado,
        completada: completa,
      ));
      montosPorCuota[n] = totalCuota;
      if (completa) totalCuotasCompletas++;
      restante -= aplicado;
    }
  }

  int? proximaCuota;
  for (var n = 1; n <= prestamo.cuotas; n++) {
    if ((montosPorCuota[n] ?? 0.0) < montoObjetivoCuota(prestamo, n) - 0.01) {
      proximaCuota = n;
      break;
    }
  }

  DateTime? fechaProximoPago;
  final fechaInicio = prestamo.fecha?.toDate();
  if (proximaCuota != null && fechaInicio != null) {
    fechaProximoPago = calcularFechaCuota(fechaInicio, prestamo.plazo, proximaCuota);
  }

  return ResultadoDistribucion(
    cuotasCubiertas: cuotasCubiertas,
    moraAplicada: moraAplicada,
    montoPagoNormal: montoPagoNormal,
    proximaCuotaPendiente: proximaCuota,
    fechaProximoPago: fechaProximoPago,
    totalCuotasCompletas: totalCuotasCompletas,
    moraHistoricaCorregida: moraHistorica,
  );
}
