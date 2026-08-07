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

/// Normaliza el texto de `plazo` (minusculas, sin tildes, sin espacios
/// sobrantes) antes de comparar. El campo viene de datos reales que a
/// veces se guardaron con variantes ("Lunes a Sabado" sin tilde, con
/// mayuscula/minuscula distinta) -- NotificacionesScreen.kt en el
/// sistema viejo ya tenia esta misma tolerancia
/// (`plazo.lowercase().trim()` + acepta "lunes a sábado"/"lunes a
/// sabado"); sin ella, un prestamo con esa variante caia en el `default`
/// (30 dias fijos en vez del calculo real que salta domingos).
String _normalizarPlazo(String plazo) {
  return plazo
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');
}

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
  switch (_normalizarPlazo(plazo)) {
    case 'diario':
      return cuotas;
    case 'lunes a sabado':
      return _contarDiasSinDomingos(cuotas, fechaInicio);
    case 'semanal':
      return _contarDiasSinDomingos(cuotas * 6, fechaInicio);
    case 'quincenal':
      return cuotas * 15;
    case 'mensual':
      return cuotas * 30;
    case 'bimestral':
      return cuotas * 60;
    default:
      return cuotas * 30;
  }
}

DateTime calcularProximaFecha(DateTime fechaInicio, String plazo) {
  switch (_normalizarPlazo(plazo)) {
    case 'diario':
      return fechaInicio.add(const Duration(days: 1));
    case 'lunes a sabado':
      var f = fechaInicio;
      do {
        f = f.add(const Duration(days: 1));
      } while (f.weekday == DateTime.sunday);
      return f;
    case 'semanal':
      return fechaInicio.add(const Duration(days: 7));
    case 'quincenal':
      return fechaInicio.add(const Duration(days: 15));
    case 'mensual':
      return DateTime(fechaInicio.year, fechaInicio.month + 1, fechaInicio.day);
    case 'bimestral':
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
    switch (_normalizarPlazo(plazo)) {
      case 'mensual':
        interesCalc = interesMes * cuotas;
        break;
      case 'lunes a sabado':
        interesCalc = interesMes * (diasEfectivos / 6.0 / 4.0);
        break;
      case 'semanal':
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
