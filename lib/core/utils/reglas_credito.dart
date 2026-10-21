import 'package:intl/intl.dart';

import '../models/pago_model.dart';
import '../models/prestamo_model.dart';
import 'cuotas_calculos.dart';
import 'currency_utils.dart';

const double tasaGeneralPct = 15;
const double reduccionPorVencimiento = 0.30;
const double incrementoPermitido = 0.20;
const int ciclosParaIncremento = 3;
const int cuotasAtrasadasParaPerderTasa = 2;

const Set<String> _estadosExcluidos = {'eliminado', 'rechazado', 'pendiente'};

final DateFormat _fmt = DateFormat('dd/MM/yyyy');

DateTime _soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

double _redondear2(double v) => (v * 100).round() / 100;

String _pct(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

String _dias(int n) => '$n ${n == 1 ? 'día' : 'días'}';

String _semanas(int n) => '$n ${n == 1 ? 'semana' : 'semanas'}';

enum CategoriaCredito {
  a('A'),
  b('B'),
  c('C');

  final String letra;
  const CategoriaCredito(this.letra);

  String get etiqueta => switch (this) {
        CategoriaCredito.a => 'Categoría A',
        CategoriaCredito.b => 'Categoría B',
        CategoriaCredito.c => 'Categoría C',
      };

  String get descripcion => switch (this) {
        CategoriaCredito.a => 'Paga a tiempo o antes de sus fechas',
        CategoriaCredito.b => 'Atrasos de 1 a 2 semanas',
        CategoriaCredito.c => 'Atrasos de 3 semanas o más',
      };

  static CategoriaCredito? desdeLetra(String? l) {
    for (final c in CategoriaCredito.values) {
      if (c.letra == l) return c;
    }
    return null;
  }
}

class CuotaAtraso {
  final int numero;
  final DateTime vencimiento;
  final DateTime? fechaCumplida;
  final int diasAtraso;
  final bool pagada;

  const CuotaAtraso({
    required this.numero,
    required this.vencimiento,
    required this.fechaCumplida,
    required this.diasAtraso,
    required this.pagada,
  });

  bool get atrasada => diasAtraso > 0;

  bool get adelantada =>
      pagada && fechaCumplida != null && _soloFecha(fechaCumplida!).isBefore(_soloFecha(vencimiento));

  int get semanasAtraso => diasAtraso <= 0 ? 0 : (diasAtraso + 6) ~/ 7;

  String get detalle {
    final venc = _fmt.format(vencimiento);
    if (!atrasada) {
      return 'Cuota $numero: le tocaba pagar el $venc'
          '${fechaCumplida != null ? ' y pagó el ${_fmt.format(fechaCumplida!)}' : ''}.';
    }
    if (pagada && fechaCumplida != null) {
      return 'Cuota $numero: le tocaba pagar el $venc y pagó el ${_fmt.format(fechaCumplida!)} '
          '(${_dias(diasAtraso)} tarde, ${_semanas(semanasAtraso)}).';
    }
    return 'Cuota $numero: le tocaba pagar el $venc y todavía no ha pagado '
        '(${_dias(diasAtraso)} de atraso, ${_semanas(semanasAtraso)}).';
  }
}

class CicloCredito {
  final PrestamoModel prestamo;
  final List<CuotaAtraso> cuotas;
  final bool saldado;
  final DateTime? vencimientoFinal;
  final DateTime? fechaSaldadoEfectiva;

  const CicloCredito({
    required this.prestamo,
    required this.cuotas,
    required this.saldado,
    required this.vencimientoFinal,
    required this.fechaSaldadoEfectiva,
  });

  String get etiqueta {
    final n = prestamo.numeroPrestamo.isEmpty ? prestamo.prestamoId : prestamo.numeroPrestamo;
    return 'N° $n';
  }

  double get totalPagar =>
      prestamo.totalPagar > 0 ? prestamo.totalPagar : prestamo.monto + prestamo.interes;

  DateTime? get fechaInicio => prestamo.fecha?.toDate() ?? prestamo.fechaCreacion?.toDate();

  List<CuotaAtraso> get cuotasAtrasadasLista => cuotas.where((c) => c.atrasada).toList();

  int get cuotasAtrasadas => cuotasAtrasadasLista.length;

  bool get pagoAlgunaCuotaAdelantada => cuotas.any((c) => c.adelantada);

  int get maxSemanasAtraso =>
      cuotas.fold<int>(0, (m, c) => c.semanasAtraso > m ? c.semanasAtraso : m);

  bool get vencidoTarde {
    final venc = vencimientoFinal;
    if (venc == null || !saldado) return false;
    final f = fechaSaldadoEfectiva;
    return f != null && _soloFecha(f).isAfter(_soloFecha(venc));
  }

  double? get tasaPct {
    final p = prestamo;
    if (p.usarInteresMensual && p.interesMensual > 0) return p.interesMensual;
    return null;
  }

  bool get tasaPreferencial {
    final t = tasaPct;
    return t != null && t < tasaGeneralPct - 0.0001;
  }
}

class EvaluacionCredito {
  final CicloCredito? ultimo;
  final CicloCredito? cicloActivo;
  final List<CicloCredito> ciclos;
  final bool tienePrestamoActivo;
  final CategoriaCredito categoria;
  final List<String> motivoCategoria;
  final String tasaTipo;
  final double tasaVigentePct;
  final bool tuvoTasaPreferencial;
  final bool perdioTasaPreferencial;
  final bool tasaAsignadaPorAdmin;
  final List<String> motivoTasa;
  final double? tasaMinimaPct;
  final double? totalMaximo;
  final List<String> motivoMonto;
  final bool limitePorVencimiento;
  final bool incrementoElegible;
  final List<String> motivoIncremento;
  final String detalleActivoAlmacenado;

  const EvaluacionCredito({
    required this.ultimo,
    required this.cicloActivo,
    required this.ciclos,
    required this.tienePrestamoActivo,
    required this.categoria,
    required this.motivoCategoria,
    required this.tasaTipo,
    required this.tasaVigentePct,
    required this.tuvoTasaPreferencial,
    required this.perdioTasaPreferencial,
    required this.tasaAsignadaPorAdmin,
    required this.motivoTasa,
    required this.tasaMinimaPct,
    required this.totalMaximo,
    required this.motivoMonto,
    required this.limitePorVencimiento,
    required this.incrementoElegible,
    required this.motivoIncremento,
    this.detalleActivoAlmacenado = '',
  });

  static EvaluacionCredito? desdeAlmacenado(Map<String, dynamic> d) {
    if (!d.containsKey('prestamoActivoCredito')) return null;
    final categoria = CategoriaCredito.desdeLetra(d['categoriaCredito'] as String?);
    if (categoria == null) return null;
    List<String> lista(String k) => (d[k] as List?)?.map((e) => e.toString()).toList() ?? const [];
    final tasaTipo = (d['tasaTipo'] ?? 'general') as String;
    final perdio = d['perdioTasaPreferencial'] == true;
    final tasaVigente = (d['tasaVigentePct'] as num?)?.toDouble() ?? tasaGeneralPct;
    return EvaluacionCredito(
      ultimo: null,
      cicloActivo: null,
      ciclos: const [],
      tienePrestamoActivo: d['prestamoActivoCredito'] == true,
      categoria: categoria,
      motivoCategoria: lista('categoriaCreditoMotivo'),
      tasaTipo: tasaTipo,
      tasaVigentePct: tasaVigente,
      tuvoTasaPreferencial: tasaTipo == 'preferencial' || perdio,
      perdioTasaPreferencial: perdio,
      tasaAsignadaPorAdmin: d['tasaAsignadaPorAdmin'] == true,
      motivoTasa: lista('tasaCreditoMotivo'),
      tasaMinimaPct: tasaTipo == 'preferencial' ? tasaVigente : tasaGeneralPct,
      totalMaximo: (d['totalMaximoCredito'] as num?)?.toDouble(),
      motivoMonto: lista('totalMaximoCreditoMotivo'),
      limitePorVencimiento: d['limitePorVencimiento'] == true,
      incrementoElegible: d['incrementoElegible'] == true,
      motivoIncremento: lista('incrementoMotivo'),
      detalleActivoAlmacenado: (d['prestamoActivoDetalle'] ?? '') as String,
    );
  }

  bool get bloqueadoPorCategoriaC => categoria == CategoriaCredito.c;

  bool get esPreferencial => tasaTipo == 'preferencial';

  String get resumenTasa {
    if (esPreferencial) return 'Tasa preferencial (${_pct(tasaVigentePct)}%)';
    if (perdioTasaPreferencial) {
      return 'Tasa general (${_pct(tasaGeneralPct)}%) — perdió la preferencial';
    }
    return 'Tasa general (${_pct(tasaGeneralPct)}%)';
  }

  String get detalleActivo {
    final c = cicloActivo;
    if (c == null) return detalleActivoAlmacenado;
    final f = c.fechaInicio;
    return 'Préstamo ${c.etiqueta}: total a pagar ${formatearLempiras(c.totalPagar)}, '
        'saldo pendiente ${formatearLempiras(c.prestamo.saldo)}'
        '${f != null ? ', iniciado el ${_fmt.format(f)}' : ''}.';
  }

  Map<String, dynamic> aMapaPersistido() => {
        'categoriaCredito': categoria.letra,
        'categoriaCreditoMotivo': motivoCategoria,
        'tasaTipo': tasaTipo,
        'tasaVigentePct': tasaVigentePct,
        'perdioTasaPreferencial': perdioTasaPreferencial,
        'tasaCreditoMotivo': motivoTasa,
        'totalMaximoCredito': totalMaximo,
        'totalMaximoCreditoMotivo': motivoMonto,
        'limitePorVencimiento': limitePorVencimiento,
        'incrementoElegible': incrementoElegible,
        'incrementoMotivo': motivoIncremento,
        'prestamoActivoCredito': tienePrestamoActivo,
        'prestamoActivoDetalle': detalleActivo,
        'tasaAsignadaPorAdmin': tasaAsignadaPorAdmin,
      };
}

bool _estaSaldado(PrestamoModel p) =>
    p.saldo <= 0.01 || p.estado == 'saldado' || p.estado == 'completado';

DateTime? _fechaInicioDe(PrestamoModel p) => p.fecha?.toDate() ?? p.fechaCreacion?.toDate();

CicloCredito construirCiclo(PrestamoModel prestamo, List<PagoModel> pagos, DateTime hoy) {
  final hoySolo = _soloFecha(hoy);
  final saldado = _estaSaldado(prestamo);
  final inicio = _fechaInicioDe(prestamo);

  final ordenados = pagos.where((p) => p.fechaPago != null).toList()
    ..sort((a, b) => a.fechaPago!.compareTo(b.fechaPago!));

  final cuotas = <CuotaAtraso>[];
  if (inicio != null) {
    var umbral = 0.0;
    for (var n = 1; n <= prestamo.cuotas; n++) {
      umbral += montoObjetivoCuota(prestamo, n);
      final vencimiento = _soloFecha(calcularFechaCuota(inicio, prestamo.plazo, n));

      DateTime? cumplida;
      var acumulado = 0.0;
      for (final pago in ordenados) {
        acumulado += pago.monto;
        if (acumulado >= umbral - 0.01) {
          cumplida = pago.fechaPago!.toDate();
          break;
        }
      }
      if (cumplida == null && saldado) {
        cumplida = ordenados.isNotEmpty
            ? ordenados.last.fechaPago!.toDate()
            : (prestamo.fechaCancelacion?.toDate() ?? hoySolo);
      }

      final pagada = cumplida != null;
      final int dias;
      if (pagada) {
        dias = _soloFecha(cumplida).difference(vencimiento).inDays;
      } else {
        dias = hoySolo.difference(vencimiento).inDays;
      }
      cuotas.add(CuotaAtraso(
        numero: n,
        vencimiento: vencimiento,
        fechaCumplida: cumplida == null ? null : _soloFecha(cumplida),
        diasAtraso: dias > 0 ? dias : 0,
        pagada: pagada,
      ));
    }
  }

  return CicloCredito(
    prestamo: prestamo,
    cuotas: cuotas,
    saldado: saldado,
    vencimientoFinal: cuotas.isEmpty ? null : cuotas.last.vencimiento,
    fechaSaldadoEfectiva: cuotas.isEmpty ? null : cuotas.last.fechaCumplida,
  );
}

DateTime _fechaOrden(PrestamoModel p) =>
    _fechaInicioDe(p) ?? DateTime.fromMillisecondsSinceEpoch(0);

CategoriaCredito categoriaDeCiclo(CicloCredito ciclo) {
  final semanas = ciclo.maxSemanasAtraso;
  if (semanas == 0) return CategoriaCredito.a;
  return semanas <= 2 ? CategoriaCredito.b : CategoriaCredito.c;
}

bool cicloPierdeTasaPreferencial(CicloCredito ciclo) =>
    ciclo.tasaPreferencial && ciclo.cuotasAtrasadas >= cuotasAtrasadasParaPerderTasa;

List<String> motivoCategoriaDeCiclo(CicloCredito ciclo) {
  final categoria = categoriaDeCiclo(ciclo);
  final atrasadas = ciclo.cuotasAtrasadasLista;
  if (atrasadas.isEmpty) {
    if (!ciclo.saldado && !ciclo.pagoAlgunaCuotaAdelantada) {
      return ['Cliente al día: su préstamo ${ciclo.etiqueta} no tiene ningún atraso.'];
    }
    if (ciclo.pagoAlgunaCuotaAdelantada) {
      return ['Cliente puntual: paga antes de sus fechas de pago (préstamo ${ciclo.etiqueta}).'];
    }
    return ['Cliente al día: paga en la fecha que le toca (préstamo ${ciclo.etiqueta}).'];
  }
  final peor = atrasadas.reduce((a, b) => a.diasAtraso >= b.diasAtraso ? a : b);
  return [
    'Se atrasó en ${atrasadas.length} ${atrasadas.length == 1 ? 'pago' : 'pagos'} del préstamo '
        '${ciclo.etiqueta}; el mayor atraso fue de ${_dias(peor.diasAtraso)} '
        '(${_semanas(peor.semanasAtraso)}), en la cuota ${peor.numero}.',
    ...atrasadas.map((c) => c.detalle),
    switch (categoria) {
      CategoriaCredito.b => 'Por eso está en Categoría B (atrasos de 1 a 2 semanas).',
      CategoriaCredito.c => 'Por eso está en Categoría C (atrasos de 3 semanas o más).',
      CategoriaCredito.a => '',
    },
  ].where((m) => m.isNotEmpty).toList();
}

EvaluacionCredito evaluarCredito({
  required List<PrestamoModel> prestamos,
  required Map<String, List<PagoModel>> pagosPorPrestamo,
  required DateTime hoy,
  double? tasaPreferencialAsignada,
  DateTime? tasaPreferencialDesde,
  bool tasaGeneralForzada = false,
}) {
  final asignada = (tasaPreferencialAsignada != null &&
          tasaPreferencialAsignada > 0 &&
          tasaPreferencialAsignada < tasaGeneralPct)
      ? tasaPreferencialAsignada
      : null;

  final validos = prestamos
      .where((p) => !p.eliminado && !_estadosExcluidos.contains(p.estado))
      .toList()
    ..sort((a, b) => _fechaOrden(a).compareTo(_fechaOrden(b)));

  final ciclos = [
    for (final p in validos) construirCiclo(p, pagosPorPrestamo[p.prestamoId] ?? const [], hoy),
  ];

  if (ciclos.isEmpty) {
    final pref = asignada != null;
    return EvaluacionCredito(
      ultimo: null,
      cicloActivo: null,
      ciclos: const [],
      tienePrestamoActivo: false,
      categoria: CategoriaCredito.a,
      motivoCategoria: const ['Cliente nuevo: todavía no tiene atrasos, por eso empieza en Categoría A.'],
      tasaTipo: pref ? 'preferencial' : 'general',
      tasaVigentePct: pref ? asignada : tasaGeneralPct,
      tuvoTasaPreferencial: pref,
      perdioTasaPreferencial: false,
      tasaAsignadaPorAdmin: pref,
      motivoTasa: [
        pref
            ? 'Tiene tasa preferencial de ${_pct(asignada)}% asignada por administración.'
            : 'Cliente nuevo: empieza con la tasa general del ${_pct(tasaGeneralPct)}%.',
      ],
      tasaMinimaPct: pref ? asignada : tasaGeneralPct,
      totalMaximo: null,
      motivoMonto: const [],
      limitePorVencimiento: false,
      incrementoElegible: false,
      motivoIncremento: const [],
    );
  }

  final ultimo = ciclos.last;
  final activos = ciclos.where((c) => !c.saldado).toList();
  final activo = activos.isNotEmpty;

  final categoria = categoriaDeCiclo(ultimo);
  final motivoCategoria = motivoCategoriaDeCiclo(ultimo);

  final forzadaGeneral = tasaGeneralForzada && asignada == null;
  final tuvoPref = asignada != null || (!forzadaGeneral && ultimo.tasaPreferencial);
  final bool perdio;
  if (forzadaGeneral) {
    perdio = false;
  } else if (asignada != null) {
    final inicioUltimo = ultimo.fechaInicio;
    final despuesDeAsignar = tasaPreferencialDesde == null ||
        inicioUltimo == null ||
        !_soloFecha(inicioUltimo).isBefore(_soloFecha(tasaPreferencialDesde));
    perdio = despuesDeAsignar && ultimo.cuotasAtrasadas >= cuotasAtrasadasParaPerderTasa;
  } else {
    perdio = cicloPierdeTasaPreferencial(ultimo);
  }

  final tasaTipo = tuvoPref && !perdio ? 'preferencial' : 'general';
  final tasaVigente = tasaTipo == 'preferencial' ? (asignada ?? ultimo.tasaPct!) : tasaGeneralPct;

  final motivoTasa = <String>[];
  if (forzadaGeneral) {
    motivoTasa.add('Administración le asignó la tasa general del ${_pct(tasaGeneralPct)}%.');
  } else if (perdio) {
    final origen = asignada != null
        ? 'Tenía tasa preferencial de ${_pct(asignada)}% asignada por administración'
        : 'Su último préstamo ${ultimo.etiqueta} tenía tasa preferencial (${_pct(ultimo.tasaPct!)}%)';
    motivoTasa.add('$origen y se atrasó en ${ultimo.cuotasAtrasadas} pagos del préstamo ${ultimo.etiqueta} '
        '(con 2 atrasos se pierde).');
    motivoTasa.addAll(ultimo.cuotasAtrasadasLista.map((c) => c.detalle));
    motivoTasa.add(
        'Pierde la tasa preferencial: su próximo préstamo será a la tasa general del ${_pct(tasaGeneralPct)}%.');
  } else if (tasaTipo == 'preferencial') {
    final atrasos = ultimo.cuotasAtrasadas;
    final nota = atrasos == 0
        ? 'no tiene atrasos'
        : 'solo se ha atrasado en 1 pago (con 2 atrasos la perdería)';
    motivoTasa.add(asignada != null
        ? 'Tiene tasa preferencial de ${_pct(asignada)}% asignada por administración y $nota.'
        : 'Su último préstamo ${ultimo.etiqueta} tiene tasa preferencial (${_pct(ultimo.tasaPct!)}%) y $nota: la conserva.');
  } else {
    motivoTasa.add('Tiene la tasa general del ${_pct(tasaGeneralPct)}%.');
  }

  double? totalMax;
  final motivoMonto = <String>[];
  var elegible = false;
  var limitePorVenc = false;
  final motivoIncremento = <String>[];

  if (!activo) {
    final base = ultimo.totalPagar;
    if (ultimo.vencidoTarde) {
      limitePorVenc = true;
      totalMax = _redondear2(base * (1 - reduccionPorVencimiento));
      motivoMonto.add(
          'Dejó vencer el préstamo ${ultimo.etiqueta}: vencía el ${_fmt.format(ultimo.vencimientoFinal!)} '
          'y lo terminó de pagar el ${_fmt.format(ultimo.fechaSaldadoEfectiva!)}.');
      motivoMonto.add(
          'Solo puede aplicar con un total a pagar ${(reduccionPorVencimiento * 100).round()}% menor: '
          'de ${formatearLempiras(base)} baja a un máximo de ${formatearLempiras(totalMax)} '
          '(total a pagar = capital + interés).');
      motivoIncremento.add('No aplica a incremento: dejó vencer su último préstamo.');
    } else {
      var consecutivos = 0;
      for (var i = ciclos.length - 1; i >= 0; i--) {
        final c = ciclos[i];
        final igual = (c.totalPagar - base).abs() < 0.5;
        if (c.saldado && igual && c.cuotasAtrasadas == 0 && !c.vencidoTarde) {
          consecutivos++;
        } else {
          break;
        }
      }
      if (consecutivos >= ciclosParaIncremento) {
        elegible = true;
        totalMax = _redondear2(base * (1 + incrementoPermitido));
        motivoIncremento.add(
            'Aplica a incremento del ${(incrementoPermitido * 100).round()}%: $consecutivos préstamos '
            'seguidos con el mismo total a pagar (${formatearLempiras(base)}) y sin atrasos.');
        motivoMonto.add(
            'Puede pedir hasta ${formatearLempiras(totalMax)} de total a pagar '
            '(incremento del ${(incrementoPermitido * 100).round()}%).');
      } else {
        totalMax = base;
        if (ultimo.cuotasAtrasadas > 0) {
          motivoIncremento.add(
              'No aplica a incremento: presentó atrasos en el préstamo ${ultimo.etiqueta} '
              '(${ultimo.cuotasAtrasadas} ${ultimo.cuotasAtrasadas == 1 ? 'pago atrasado' : 'pagos atrasados'}).');
        } else {
          motivoIncremento.add(
              'No aplica a incremento todavía: lleva $consecutivos de $ciclosParaIncremento préstamos '
              'seguidos con el mismo total a pagar (${formatearLempiras(base)}) y sin atrasos.');
        }
        motivoMonto.add(
            'No puede pedir más que su último total a pagar (${formatearLempiras(totalMax)}).');
      }
    }
  }

  return EvaluacionCredito(
    ultimo: ultimo,
    cicloActivo: activo ? activos.last : null,
    ciclos: ciclos,
    tienePrestamoActivo: activo,
    categoria: categoria,
    motivoCategoria: motivoCategoria,
    tasaTipo: tasaTipo,
    tasaVigentePct: tasaVigente,
    tuvoTasaPreferencial: tuvoPref,
    perdioTasaPreferencial: perdio,
    tasaAsignadaPorAdmin: asignada != null,
    motivoTasa: motivoTasa,
    tasaMinimaPct: tasaTipo == 'preferencial' ? tasaVigente : tasaGeneralPct,
    totalMaximo: totalMax,
    motivoMonto: motivoMonto,
    limitePorVencimiento: limitePorVenc,
    incrementoElegible: elegible,
    motivoIncremento: motivoIncremento,
  );
}

enum TipoViolacion { prestamoActivo, categoriaC, montoExcedido, tasaInferior }

class ViolacionCredito {
  final TipoViolacion tipo;
  final String mensaje;

  const ViolacionCredito(this.tipo, this.mensaje);
}

List<ViolacionCredito> validarNuevoPrestamo({
  required EvaluacionCredito evaluacion,
  required double totalAPagar,
  required double interesMensualPct,
  String? prestamoActivoExterno,
}) {
  final v = <ViolacionCredito>[];

  if (evaluacion.tienePrestamoActivo) {
    v.add(ViolacionCredito(
        TipoViolacion.prestamoActivo,
        'Este cliente no se puede elegir porque ya cuenta con un préstamo activo. '
        '${evaluacion.detalleActivo}'));
  } else if (prestamoActivoExterno != null) {
    v.add(ViolacionCredito(
        TipoViolacion.prestamoActivo,
        'Este cliente no se puede elegir porque ya cuenta con un préstamo activo. $prestamoActivoExterno'));
  }

  if (evaluacion.bloqueadoPorCategoriaC) {
    v.add(ViolacionCredito(
        TipoViolacion.categoriaC,
        'No aplica a nuevo préstamo por atrasos (Categoría C). '
        '${evaluacion.motivoCategoria.isNotEmpty ? evaluacion.motivoCategoria.first : ''}'
            .trim()));
  }

  final max = evaluacion.totalMaximo;
  if (max != null && totalAPagar > max + 0.01) {
    final motivo = evaluacion.motivoMonto.isNotEmpty ? ' ${evaluacion.motivoMonto.join(' ')}' : '';
    final incr = !evaluacion.incrementoElegible && evaluacion.motivoIncremento.isNotEmpty
        ? ' ${evaluacion.motivoIncremento.join(' ')}'
        : '';
    v.add(ViolacionCredito(
        TipoViolacion.montoExcedido,
        'El total a pagar de este préstamo (${formatearLempiras(totalAPagar)}) supera el máximo '
        'permitido de ${formatearLempiras(max)}.$motivo$incr'));
  }

  final minTasa = evaluacion.tasaMinimaPct;
  if (minTasa != null && interesMensualPct < minTasa - 0.0001) {
    final texto = evaluacion.esPreferencial
        ? 'La tasa preferencial de este cliente es del ${_pct(minTasa)}%. Usar ${_pct(interesMensualPct)}% (menor) requiere autorización especial.'
        : 'La tasa de este cliente es la general del ${_pct(minTasa)}%. Usar ${_pct(interesMensualPct)}% (menor) requiere autorización especial.';
    v.add(ViolacionCredito(TipoViolacion.tasaInferior, texto));
  }

  return v;
}
