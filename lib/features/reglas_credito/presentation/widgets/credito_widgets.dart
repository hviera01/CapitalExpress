import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/reglas_credito.dart';
import '../../../../core/utils/uppercase_text_formatter.dart';
import '../../data/reglas_credito_service.dart';

Color colorCategoriaCredito(String letra) => switch (letra) {
      'A' => CEColors.success,
      'B' => CEColors.warning,
      'C' => CEColors.danger,
      _ => CEColors.textSecondary,
    };

class CategoriaCreditoChip extends StatelessWidget {
  final String letra;
  final VoidCallback? onTap;
  final bool grande;

  const CategoriaCreditoChip({super.key, required this.letra, this.onTap, this.grande = false});

  @override
  Widget build(BuildContext context) {
    if (letra.isEmpty) return const SizedBox.shrink();
    final color = colorCategoriaCredito(letra);
    final lado = grande ? 40.0 : 24.0;
    final chip = Container(
      width: lado,
      height: lado,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(grande ? 10 : 6),
        border: Border.all(color: color, width: grande ? 2 : 1.4),
      ),
      child: Text(
        letra,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: grande ? 20 : 13,
        ),
      ),
    );
    if (onTap == null) return Tooltip(message: 'Categoría $letra', child: chip);
    return Tooltip(
      message: 'Categoría $letra — toque para ver el detalle',
      child: InkWell(borderRadius: BorderRadius.circular(8), onTap: onTap, child: chip),
    );
  }
}

class TasaCreditoChip extends StatelessWidget {
  final String tipo;
  final bool perdio;
  final double? pct;

  const TasaCreditoChip({super.key, required this.tipo, this.perdio = false, this.pct});

  @override
  Widget build(BuildContext context) {
    if (tipo.isEmpty) return const SizedBox.shrink();
    final preferencial = tipo == 'preferencial';
    final color = preferencial ? CEColors.accent : CEColors.textSecondary;
    final sufijo = pct == null ? '' : ' ${pct!.toStringAsFixed(pct! == pct!.roundToDouble() ? 0 : 2)}%';
    final texto = preferencial
        ? 'Tasa preferencial$sufijo'
        : (perdio ? 'Tasa general (perdió la preferencial)' : 'Tasa general$sufijo');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(texto, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class EtiquetaCreditoChip extends StatelessWidget {
  final String texto;
  final Color color;

  const EtiquetaCreditoChip({super.key, required this.texto, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(texto, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

enum AccionBloqueoCredito { cerrar, autorizar, pedirAutorizacion }

Future<AccionBloqueoCredito> mostrarBloqueoCredito(
  BuildContext context, {
  required List<ViolacionCredito> violaciones,
  required bool esAdmin,
  required bool permitirAutorizar,
  String titulo = 'No se puede registrar el préstamo',
  String textoCerrar = 'Entendido',
}) async {
  final resultado = await showDialog<AccionBloqueoCredito>(
    context: context,
    useRootNavigator: false,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.block, color: CEColors.danger, size: 32),
      title: Text(titulo),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final v in violaciones)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2, right: 8),
                        child: Icon(Icons.error_outline, size: 16, color: CEColors.danger),
                      ),
                      Expanded(child: Text(v.mensaje, style: const TextStyle(height: 1.35))),
                    ],
                  ),
                ),
              if (permitirAutorizar)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: CEColors.iconBadgeBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    esAdmin
                        ? 'Como administrador puede dar una autorización especial. Quedará registrada a su nombre.'
                        : 'Puede pedir una autorización especial: la solicitud le llegará al administrador, que decide si la aprueba.',
                    style: const TextStyle(fontSize: 12.5, color: CEColors.textSecondary),
                  ),
                ),
            ],
          ),
        ),
      ),
      actionsOverflowButtonSpacing: 6,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(AccionBloqueoCredito.cerrar),
          child: Text(textoCerrar),
        ),
        if (permitirAutorizar)
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: CEColors.danger),
            onPressed: () => Navigator.of(ctx)
                .pop(esAdmin ? AccionBloqueoCredito.autorizar : AccionBloqueoCredito.pedirAutorizacion),
            child: Text(esAdmin ? 'Autorizar excepción' : 'Pedir autorización especial'),
          ),
      ],
    ),
  );
  return resultado ?? AccionBloqueoCredito.cerrar;
}

Future<({double? pct, String nota})?> mostrarDialogoTasaCliente(
  BuildContext context, {
  required String clienteNombre,
  required bool esPreferencialActual,
  required double pctActual,
}) {
  final pctCtrl = TextEditingController(text: esPreferencialActual ? pctActual.toString() : '');
  final notaCtrl = TextEditingController();
  var preferencial = esPreferencialActual;
  String? error;
  return showDialog<({double? pct, String nota})>(
    context: context,
    useRootNavigator: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Tasa del cliente'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(clienteNombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: false, label: Text('General ${tasaGeneralPct.toStringAsFixed(0)}%')),
                    const ButtonSegment(value: true, label: Text('Preferencial')),
                  ],
                  selected: {preferencial},
                  onSelectionChanged: (s) => setState(() {
                    preferencial = s.first;
                    error = null;
                  }),
                ),
                if (preferencial) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: pctCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Porcentaje mensual (menor a ${tasaGeneralPct.toStringAsFixed(0)})',
                      suffixText: '%',
                      errorText: error,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: notaCtrl,
                  inputFormatters: const [upperCaseTextFormatter],
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Motivo del cambio (opcional)'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Queda en el historial del cliente. Si con tasa preferencial se atrasa en 2 pagos de un préstamo posterior, la pierde sola.',
                  style: TextStyle(fontSize: 12, color: CEColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (!preferencial) {
                Navigator.of(ctx).pop((pct: null, nota: notaCtrl.text));
                return;
              }
              final v = double.tryParse(pctCtrl.text.replaceAll(',', '.'));
              if (v == null || v <= 0 || v >= tasaGeneralPct) {
                setState(() => error = 'Debe ser mayor que 0 y menor que ${tasaGeneralPct.toStringAsFixed(0)}');
                return;
              }
              Navigator.of(ctx).pop((pct: v, nota: notaCtrl.text));
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
}

Future<void> mostrarDetalleCreditoCliente(
  BuildContext context, {
  required String clienteId,
  required String clienteNombre,
}) {
  return showDialog<void>(
    context: context,
    useRootNavigator: false,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      clienteNombre,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(ctx).pop()),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: PanelSeguimientoCredito(clienteId: clienteId, clienteNombre: clienteNombre),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class PanelSeguimientoCredito extends StatefulWidget {
  final String clienteId;
  final String clienteNombre;
  final String usuario;
  final String usuarioUid;
  final bool esAdmin;

  const PanelSeguimientoCredito({
    super.key,
    required this.clienteId,
    required this.clienteNombre,
    this.usuario = '',
    this.usuarioUid = '',
    this.esAdmin = false,
  });

  @override
  State<PanelSeguimientoCredito> createState() => _PanelSeguimientoCreditoState();
}

class _PanelSeguimientoCreditoState extends State<PanelSeguimientoCredito> {
  final _servicio = ReglasCreditoService();
  EvaluacionCredito? _evaluacion;
  bool _actualizando = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    setState(() {
      _actualizando = true;
      _error = null;
    });
    _servicio.evaluacionAlmacenada(widget.clienteId).then((guardada) {
      if (mounted && guardada != null && _actualizando) setState(() => _evaluacion = guardada);
    }).catchError((_) {});
    try {
      final viva = await _servicio.evaluarYPersistir(
        widget.clienteId,
        origen: 'consulta',
        usuario: widget.usuario,
      );
      if (!mounted) return;
      setState(() {
        _evaluacion = viva ?? _evaluacion;
        _actualizando = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err;
        _actualizando = false;
      });
    }
  }

  Future<void> _cambiarTasa(EvaluacionCredito e) async {
    final r = await mostrarDialogoTasaCliente(
      context,
      clienteNombre: widget.clienteNombre,
      esPreferencialActual: e.esPreferencial,
      pctActual: e.tasaVigentePct,
    );
    if (r == null) return;
    try {
      await _servicio.asignarTasaPreferencial(
        clienteId: widget.clienteId,
        clienteNombre: widget.clienteNombre,
        pct: r.pct,
        usuarioUid: widget.usuarioUid,
        usuarioNombre: widget.usuario,
        nota: r.nota,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(r.pct == null ? 'Tasa general del 15% asignada' : 'Tasa preferencial asignada')),
      );
      await _iniciar();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo cambiar la tasa: $err')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _evaluacion;
    if (e == null) {
      if (_error != null) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text('No se pudo calcular la categoría: $_error',
              style: const TextStyle(color: CEColors.danger)),
        );
      }
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_actualizando)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        _encabezado(e),
        const SizedBox(height: 14),
        _bloque(titulo: 'Por qué está en ${e.categoria.etiqueta}', lineas: e.motivoCategoria),
        const SizedBox(height: 12),
        _bloque(
          titulo: e.resumenTasa,
          lineas: e.motivoTasa,
          accion: widget.esAdmin
              ? TextButton.icon(
                  onPressed: _actualizando ? null : () => _cambiarTasa(e),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Cambiar tasa'),
                )
              : null,
        ),
        const SizedBox(height: 12),
        _bloque(titulo: 'Para su próximo préstamo', lineas: _lineasProximo(e)),
        const SizedBox(height: 16),
        const Text('Historial de cambios', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: 6),
        _HistorialEventos(clienteId: widget.clienteId, servicio: _servicio),
      ],
    );
  }

  List<String> _lineasProximo(EvaluacionCredito e) {
    final l = <String>[];
    if (e.tienePrestamoActivo) {
      l.add('Tiene un préstamo activo, no se le puede crear otro hasta que lo salde (salvo autorización especial del administrador). ${e.detalleActivo}');
    }
    if (e.bloqueadoPorCategoriaC) {
      l.add('No aplica a nuevo préstamo por atrasos (Categoría C).');
    }
    l.addAll(e.motivoMonto);
    l.addAll(e.motivoIncremento);
    if (e.perdioTasaPreferencial) {
      l.add('Debe aplicarse la tasa general del ${tasaGeneralPct.toStringAsFixed(0)}%.');
    }
    if (l.isEmpty) l.add('Sin restricciones para un próximo préstamo.');
    return l;
  }

  Widget _encabezado(EvaluacionCredito e) {
    return Row(
      children: [
        CategoriaCreditoChip(letra: e.categoria.letra, grande: true),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.categoria.etiqueta, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text(e.categoria.descripcion,
                  style: const TextStyle(color: CEColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  TasaCreditoChip(tipo: e.tasaTipo, perdio: e.perdioTasaPreferencial, pct: e.tasaVigentePct),
                  if (e.incrementoElegible) _etiqueta('Aplica a incremento', CEColors.success),
                  if (e.limitePorVencimiento) _etiqueta('Total limitado (dejó vencer)', CEColors.danger),
                  if (e.tienePrestamoActivo) _etiqueta('Con préstamo activo', CEColors.accent),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _etiqueta(String texto, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Text(texto, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      );

  Widget _bloque({required String titulo, required List<String> lineas, Widget? accion}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CEColors.iconBadgeBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
              ?accion,
            ],
          ),
          const SizedBox(height: 6),
          for (final l in lineas)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6, right: 8),
                    child: Icon(Icons.circle, size: 5, color: CEColors.textSecondary),
                  ),
                  Expanded(child: Text(l, style: const TextStyle(fontSize: 12.5, height: 1.35))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _HistorialEventos extends StatelessWidget {
  final String clienteId;
  final ReglasCreditoService servicio;

  const _HistorialEventos({required this.clienteId, required this.servicio});

  @override
  Widget build(BuildContext context) {
    final formato = DateFormat('dd/MM/yyyy HH:mm');
    return StreamBuilder<List<EventoCredito>>(
      stream: servicio.streamEventos(clienteId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          );
        }
        final eventos = snap.data!;
        if (eventos.isEmpty) {
          return const Text(
            'Todavía no hay cambios registrados. Cada vez que cambie de categoría, tasa o total permitido, quedará aquí con su motivo.',
            style: TextStyle(color: CEColors.textSecondary, fontSize: 12),
          );
        }
        return Column(
          children: [
            for (final ev in eventos)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: CEColors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                    childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    leading: Icon(_icono(ev.tipo), size: 20, color: _color(ev)),
                    title: Text(ev.titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                    subtitle: Text(
                      '${ev.fecha != null ? formato.format(ev.fecha!) : 'Registrando...'}'
                      '${ev.usuario.isNotEmpty ? ' · ${ev.usuario}' : ''}'
                      ' · ${_origen(ev.origen)}',
                      style: const TextStyle(fontSize: 11, color: CEColors.textSecondary),
                    ),
                    children: [
                      for (final m in ev.motivo)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('• $m', style: const TextStyle(fontSize: 12, height: 1.35)),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  IconData _icono(String tipo) => switch (tipo) {
        'categoria' => Icons.swap_vert,
        'tasa' => Icons.percent,
        'incremento' => Icons.trending_up,
        'monto' => Icons.payments_outlined,
        'excepcion' => Icons.gavel_outlined,
        _ => Icons.info_outline,
      };

  Color _color(EventoCredito ev) {
    if (ev.tipo == 'categoria') return colorCategoriaCredito(ev.nuevo);
    if (ev.tipo == 'tasa' && ev.nuevo == 'general') return CEColors.warning;
    if (ev.tipo == 'excepcion') return CEColors.danger;
    return CEColors.accent;
  }

  String _origen(String o) => switch (o) {
        'pago' => 'por un pago',
        'prestamo' => 'por un préstamo nuevo',
        'recalculo' => 'recálculo manual',
        'automatico' => 'revisión diaria',
        'consulta' => 'al consultar',
        'excepcion' => 'autorización especial',
        'administracion' => 'cambio de administración',
        _ => o,
      };
}
