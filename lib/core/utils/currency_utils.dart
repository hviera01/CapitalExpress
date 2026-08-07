import 'package:intl/intl.dart';

final _formatoLempiras = NumberFormat.currency(locale: 'es_HN', symbol: 'L.', decimalDigits: 2);

/// Mismo formato que CurrencyUtils.kt (formatearLempiras): "L.1,200.00".
String formatearLempiras(num valor) => _formatoLempiras.format(valor);
