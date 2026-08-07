import 'package:intl/intl.dart';

// Formato fijo (no depende del locale del dispositivo/navegador): coma de
// miles, punto decimal, 2 decimales — "L.1,200.00" — igual que
// CurrencyUtils.kt (formatearLempiras). Usar 'en_US' explicito en vez de
// 'es_HN' porque ICU formatea es_HN con punto de miles/coma decimal, al
// reves de lo que espera la app.
final _formatoLempiras = NumberFormat('#,##0.00', 'en_US');

String formatearLempiras(num valor) => 'L.${_formatoLempiras.format(valor)}';
