import 'package:flutter/material.dart';
import '../../../../core/constants/texto_reestructura.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/models/prestamo_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_utils.dart';
import '../../../../core/utils/prestamo_calculos.dart';
import '../../../../core/utils/reglas_credito.dart' show tasaGeneralPct;
import '../../../../core/utils/uppercase_text_formatter.dart';
import '../../../../core/widgets/ce_scaffold.dart';
import '../../../../core/widgets/ce_section_card.dart';
import '../../../../core/widgets/exito_transaccion_overlay.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../reglas_credito/presentation/widgets/credito_widgets.dart';
import '../../data/reestructuracion_service.dart';

class ReestructurarPrestamoScreen extends ConsumerStatefulWidget {
  final PrestamoModel prestamo;

  const ReestructurarPrestamoScreen({super.key, required this.prestamo});

  @override
  ConsumerState<ReestructurarPrestamoScreen> createState() => _ReestructurarPrestamoScreenState();
}

class _ReestructurarPrestamoScreenState extends ConsumerState<ReestructurarPrestamoScreen> {
  final _fmt = DateFormat('dd/MM/yyyy');
  late final TextEditingController _interesCtrl;
  late final TextEditingController _cuotasCtrl;
  final _motivoCtrl = TextEditingController();
  late String _plazo;
  bool _incluirMora = true;
  DateTime _fechaInicio = DateTime.now();
  bool _guardando = false;

  PrestamoModel get _p => widget.prestamo;

  @override
  void initState() {
    super.initState();
    final tasa = _p.usarInteresMensual && _p.interesMensual > 0 ? _p.interesMensual : tasaGeneralPct;
    _interesCtrl = TextEditingController(text: _fmtPct(tasa));
    _cuotasCtrl = TextEditingController(text: '${_p.cuotas > 0 ? _p.cuotas * 2 : 8}');
    _plazo = plazosDisponibles.contains(_p.plazo) ? _p.plazo : 'Semanal';
  }

  @override
  void dispose() {
    _interesCtrl.dispose();
    _cuotasCtrl.dispose();
    _motivoCtrl.dispose();
    super.dispose();
  }

  String _fmtPct(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  PropuestaReestructuracion get _propuesta => PropuestaReestructuracion(
        saldoActual: _p.saldo,
        moraActual: _p.mora,
        incluirMora: _incluirMora,
        interesMensualPct: double.tryParse(_interesCtrl.text.replaceAll(',', '.')) ?? -1,
        cuotas: int.tryParse(_cuotasCtrl.text) ?? 0,
        plazo: _plazo,
        fechaInicio: _fechaInicio,
      );

  Future<void> _confirmar() async {
    final pr = _propuesta;
    if (!pr.valida) {
      _aviso('Revise el número de cuotas y el interés mensual.');
      return;
    }
    if (_motivoCtrl.text.trim().isEmpty) {
      _aviso('Escriba el motivo de la ${TxtR.sust} (queda en el historial del cliente).');
      return;
    }
    final c = pr.calculo;
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.sync_alt, color: colorReestructurado, size: 32),
        title: const Text('¿${TxtR.verboMay} el préstamo?'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Text(
            'El préstamo N° ${_p.numeroPrestamo} se cierra como ${TxtR.partUp} y se crea uno nuevo por '
            '${formatearLempiras(pr.base)} en ${pr.cuotas} cuotas de ${formatearLempiras(c.cuotaEstimada)} '
            '(total a pagar ${formatearLempiras(c.totalAPagar)}).\n\n'
            '${_p.cliente} quedará marcado como cliente ${TxtR.part} y el sistema bloqueará '
            'nuevos préstamos para él (solo con autorización especial del administrador).\n\n'
            'Esta acción no se puede deshacer.',
            style: const TextStyle(height: 1.4),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Volver')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colorReestructurado),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sí, ${TxtR.verbo}'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _guardando = true);
    try {
      final usuario = ref.read(authProvider).usuario!;
      final r = await ReestructuracionService().reestructurar(
        original: _p,
        propuesta: pr,
        motivo: _motivoCtrl.text,
        usuarioUid: usuario.uid,
        usuarioNombre: usuario.nombre,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Préstamo ${TxtR.part}: nuevo N° ${r.numero}')),
      );
      mostrarExitoTransaccion(context, mensaje: 'Préstamo ${TxtR.part} correctamente');
      Navigator.of(context).pop(r.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      _aviso('No se pudo ${TxtR.verbo}: ${e is StateError ? e.message : e}');
    }
  }

  void _aviso(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  @override
  Widget build(BuildContext context) {
    final pr = _propuesta;
    final c = pr.valida ? pr.calculo : null;
    return CeScaffold(
      maxWidth: 720,
      appBar: AppBar(leading: const BackButton(), title: const Text('${TxtR.verboMay} Préstamo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorReestructurado.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colorReestructurado.withValues(alpha: 0.5)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: colorReestructurado, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Para clientes que no pueden pagar en tiempo y forma pero tienen voluntad de pago: '
                    'el saldo pendiente pasa a un préstamo nuevo con más cuotas, cuota más baja y más intereses. '
                    'El cliente queda etiquetado como ${TxtR.partUp} y no se le darán más préstamos.',
                    style: TextStyle(fontSize: 12.5, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          CeSectionCard(
            numero: 1,
            icono: Icons.receipt_long_outlined,
            titulo: 'Préstamo actual',
            child: Column(
              children: [
                _fila('Cliente', _p.cliente),
                _fila('Préstamo', 'N° ${_p.numeroPrestamo}'),
                _fila('Cuotas', '${_p.cuotas} de ${formatearLempiras(_p.cuota)} (${_p.plazo.toLowerCase()})'),
                _fila('Total a pagar', formatearLempiras(_p.totalPagar)),
                _fila('Pagado', formatearLempiras(_p.montoPagado), color: CEColors.success),
                if (_p.mora > 0.01) _fila('Mora incluida en el saldo', formatearLempiras(_p.mora), color: CEColors.danger),
                const Divider(height: 20),
                _fila('Saldo pendiente', formatearLempiras(_p.saldo), negrita: true, color: CEColors.danger),
              ],
            ),
          ),
          const SizedBox(height: 14),
          CeSectionCard(
            numero: 2,
            icono: Icons.tune,
            titulo: 'Nuevas condiciones',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_p.mora > 0.01)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _incluirMora,
                    onChanged: (v) => setState(() => _incluirMora = v),
                    title: Text('Pasar la mora (${formatearLempiras(_p.mora)}) al nuevo préstamo'),
                    subtitle: Text(_incluirMora ? 'Se cobra dentro de las nuevas cuotas' : 'La mora se perdona'),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _cuotasCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: 'Número de cuotas'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _plazo,
                        decoration: const InputDecoration(labelText: 'Plazo'),
                        items: plazosDisponibles
                            .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                            .toList(),
                        onChanged: (v) => setState(() => _plazo = v ?? _plazo),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _interesCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Interés mensual', suffixText: '%'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final f = await showDatePicker(
                            context: context,
                            initialDate: _fechaInicio,
                            firstDate: DateTime.now().subtract(const Duration(days: 60)),
                            lastDate: DateTime.now().add(const Duration(days: 60)),
                          );
                          if (f != null) setState(() => _fechaInicio = f);
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Fecha de inicio'),
                          child: Text(_fmt.format(_fechaInicio)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _motivoCtrl,
                  inputFormatters: const [upperCaseTextFormatter],
                  textCapitalization: TextCapitalization.characters,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Motivo (obligatorio)',
                    hintText: 'EJ. PERDIÓ EL EMPLEO, ENFERMEDAD, BAJARON LAS VENTAS...',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          CeSectionCard(
            numero: 3,
            icono: Icons.compare_arrows,
            titulo: 'Antes y después',
            child: c == null
                ? const Text('Escriba el número de cuotas y el interés para ver el cálculo.',
                    style: TextStyle(color: CEColors.textSecondary))
                : Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _caja('ANTES', '${_p.cuotas} cuotas', formatearLempiras(_p.cuota),
                                CEColors.textSecondary),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(Icons.arrow_forward, color: CEColors.textSecondary),
                          ),
                          Expanded(
                            child: _caja('AHORA', '${pr.cuotas} cuotas', formatearLempiras(c.cuotaEstimada),
                                colorReestructurado),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _fila('Capital del nuevo préstamo', formatearLempiras(pr.base)),
                      _fila('Interés nuevo (${_fmtPct(pr.interesMensualPct)}% mensual)',
                          formatearLempiras(c.interesCalculado),
                          color: CEColors.warning),
                      _fila('Nuevo total a pagar', formatearLempiras(c.totalAPagar), negrita: true),
                      _fila('Días efectivos', '${pr.diasEfectivos}'),
                      _fila('Primer pago',
                          _fmt.format(calcularProximaFecha(_fechaInicio, _plazo))),
                      if (_p.cuota > 0 && c.cuotaEstimada >= _p.cuota)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Ojo: la cuota nueva no es más baja que la anterior. Aumente el número de cuotas.',
                            style: TextStyle(color: CEColors.danger, fontWeight: FontWeight.w600, fontSize: 12.5),
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: colorReestructurado, shape: const StadiumBorder()),
              onPressed: _guardando ? null : _confirmar,
              icon: _guardando
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.sync_alt),
              label: Text(_guardando ? '${TxtR.gerundioMay}...' : '${TxtR.verboMay} préstamo'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _fila(String label, String valor, {Color? color, bool negrita = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(label, style: const TextStyle(color: CEColors.textSecondary, fontSize: 13))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              valor,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: negrita ? FontWeight.w800 : FontWeight.w600,
                fontSize: negrita ? 16 : 13,
                color: color ?? CEColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _caja(String titulo, String sub, String valor, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(valor, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: color)),
          Text(sub, style: const TextStyle(fontSize: 11.5, color: CEColors.textSecondary)),
        ],
      ),
    );
  }
}
