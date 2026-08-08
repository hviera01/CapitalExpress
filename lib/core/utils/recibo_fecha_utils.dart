/// Formateo de fecha/hora compartido por los recibos (abono y prestamo)
/// -- siempre 12h con AM/PM, igual que formatearFechaPago12h() en el
/// sistema viejo ("dd/MM/yyyy hh:mm a"), nunca 24h.
String f2(int n) => n.toString().padLeft(2, '0');

String fechaCorta(DateTime d) => '${f2(d.day)}/${f2(d.month)}/${d.year}';

String _hora12(DateTime d) {
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final ampm = d.hour < 12 ? 'AM' : 'PM';
  return '${f2(h12)}:${f2(d.minute)} $ampm';
}

String _hora12ConSegundos(DateTime d) {
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final ampm = d.hour < 12 ? 'AM' : 'PM';
  return '${f2(h12)}:${f2(d.minute)}:${f2(d.second)} $ampm';
}

String fechaHoraCorta(DateTime d) => '${fechaCorta(d)} ${_hora12(d)}';

String fechaHoraConSegundos(DateTime d) => '${fechaCorta(d)} ${_hora12ConSegundos(d)}';
