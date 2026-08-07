/// Mismas formulas que CrearPrestamoScreen.kt (calcularDiasEfectivos +
/// el bloque de calculo de interes/cuota), portadas literal para que los
/// prestamos den los mismos numeros en ambas apps.
library;

const List<String> plazosDisponibles = [
  'Diario',
  'Lunes a Sábado',
  'Semanal',
  'Quincenal',
  'Mensual',
  'Bimestral',
];

int _contarDiasSinDomingos(int cantidadDias, DateTime desde) {
  var dias = 0;
  var fecha = desde;
  var contados = 0;
  while (contados < cantidadDias) {
    fecha = fecha.add(const Duration(days: 1));
    dias++;
    if (fecha.weekday != DateTime.sunday) {
      contados++;
    }
  }
  return dias;
}

int calcularDiasEfectivos(String plazo, int cuotas, DateTime fechaInicio) {
  switch (plazo) {
    case 'Diario':
      return cuotas;
    case 'Lunes a Sábado':
      return _contarDiasSinDomingos(cuotas, fechaInicio);
    case 'Semanal':
      return _contarDiasSinDomingos(cuotas * 6, fechaInicio);
    case 'Quincenal':
      return cuotas * 15;
    case 'Mensual':
      return cuotas * 30;
    case 'Bimestral':
      return cuotas * 60;
    default:
      return cuotas * 30;
  }
}

DateTime calcularProximaFecha(DateTime fechaInicio, String plazo) {
  switch (plazo) {
    case 'Diario':
      return fechaInicio.add(const Duration(days: 1));
    case 'Lunes a Sábado':
      var f = fechaInicio;
      do {
        f = f.add(const Duration(days: 1));
      } while (f.weekday == DateTime.sunday);
      return f;
    case 'Semanal':
      return fechaInicio.add(const Duration(days: 7));
    case 'Quincenal':
      return fechaInicio.add(const Duration(days: 15));
    case 'Mensual':
      return DateTime(fechaInicio.year, fechaInicio.month + 1, fechaInicio.day);
    case 'Bimestral':
      return DateTime(fechaInicio.year, fechaInicio.month + 2, fechaInicio.day);
    default:
      return fechaInicio.add(const Duration(days: 30));
  }
}

class ResultadoCalculoPrestamo {
  final double interesCalculado;
  final double totalAPagar;
  final double cuotaEstimada;

  const ResultadoCalculoPrestamo({
    required this.interesCalculado,
    required this.totalAPagar,
    required this.cuotaEstimada,
  });
}

/// [usarInteresMensual] = true -> [interesPct] es un % mensual sobre el
/// monto, prorrateado segun el plazo. false -> [interesTotalFijo] ya es
/// el interes total en Lempiras (no porcentaje).
ResultadoCalculoPrestamo calcularInteresYCuota({
  required double monto,
  required int cuotas,
  required String plazo,
  required int diasEfectivos,
  required bool usarInteresMensual,
  required double interesPct,
  required double interesTotalFijo,
}) {
  final cuotasSeguras = cuotas > 0 ? cuotas : 1;

  if (!usarInteresMensual && interesTotalFijo > 0) {
    final total = monto + interesTotalFijo;
    return ResultadoCalculoPrestamo(
      interesCalculado: interesTotalFijo,
      totalAPagar: total,
      cuotaEstimada: cuotas > 0 ? (total / cuotasSeguras).roundToDouble() : 0,
    );
  }

  if (usarInteresMensual && interesPct > 0) {
    final interesMes = monto * (interesPct / 100);
    final double interesCalc;
    switch (plazo) {
      case 'Mensual':
        interesCalc = interesMes * cuotas;
        break;
      case 'Lunes a Sábado':
        interesCalc = interesMes * (diasEfectivos / 6.0 / 4.0);
        break;
      case 'Semanal':
        interesCalc = interesMes * (cuotas / 4.0);
        break;
      default:
        interesCalc = interesMes * (diasEfectivos / 30.0);
    }
    final total = monto + interesCalc;
    return ResultadoCalculoPrestamo(
      interesCalculado: interesCalc,
      totalAPagar: total,
      cuotaEstimada: cuotas > 0 ? (total / cuotasSeguras).roundToDouble() : 0,
    );
  }

  return ResultadoCalculoPrestamo(
    interesCalculado: 0,
    totalAPagar: monto,
    cuotaEstimada: monto / cuotasSeguras,
  );
}
