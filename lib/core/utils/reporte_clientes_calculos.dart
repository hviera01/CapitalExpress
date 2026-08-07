import '../models/prestamo_model.dart';
import 'firestore_parse.dart';

/// Mismas formulas que ReporteClienteScreen.kt (estadoEfectivo,
/// totalesCliente, proximoPagoCliente) portadas literal para que el
/// "pendiente"/"saldo" que ve el usuario sea siempre el mismo numero,
/// lo mire desde donde lo mire (Resumen de Cliente, este reporte, y
/// cualquier pantalla futura que toque el mismo calculo).
class TotalesCliente {
  final double prestado;
  final double abonado;
  final double pendiente; // saldo total, YA incluye la mora
  final double mora; // mora sola, para mostrarla desglosada aparte

  const TotalesCliente({
    this.prestado = 0,
    this.abonado = 0,
    this.pendiente = 0,
    this.mora = 0,
  });

  /// Pendiente sin contar la mora (capital + interes que falta pagar).
  double get pendienteSinMora => (pendiente - mora).clamp(0, double.infinity);
}

double _prestadoDe(PrestamoModel p) => p.totalPagar > 0 ? p.totalPagar : (p.monto + p.interes);

TotalesCliente totalesCliente(List<PrestamoModel> prestamos) {
  var prestado = 0.0, abonado = 0.0, pendiente = 0.0, mora = 0.0;
  for (final p in prestamos) {
    prestado += _prestadoDe(p);
    abonado += p.montoPagado;
    // "pendiente" es siempre el campo `saldo` del prestamo (no un
    // total-montoPagado recalculado): `saldo` es el que se actualiza
    // cuando se aplica una mora (Cobros -> Aplicar Mora se la suma), asi
    // que ya viene con la mora incluida. Ademas se expone `mora` sola
    // para poder mostrar el desglose (cuanto es capital+interes vs.
    // cuanto es mora) sin perder el total combinado.
    pendiente += p.saldo;
    mora += p.mora;
  }
  return TotalesCliente(prestado: prestado, abonado: abonado, pendiente: pendiente, mora: mora);
}

/// 'saldado' si no le queda nada pendiente en ningun prestamo (o el
/// cliente esta marcado saldado a mano), 'inactivo' si esta desactivado,
/// 'activo' en cualquier otro caso.
String estadoEfectivoCliente({
  required String estadoCliente,
  required List<PrestamoModel> prestamos,
}) {
  final todosSaldados = prestamos.isNotEmpty &&
      prestamos.every((p) {
        final total = _prestadoDe(p);
        final pagado = p.montoPagado;
        return (total - pagado) <= 0.01 ||
            p.estado.toLowerCase() == 'saldado' ||
            p.estado.toLowerCase() == 'completado';
      });

  if (todosSaldados || estadoCliente.toLowerCase() == 'saldado') return 'saldado';
  if (estadoCliente.toLowerCase() == 'inactivo') return 'inactivo';
  return 'activo';
}

DateTime? proximoPagoCliente(List<PrestamoModel> prestamos) {
  final hoy = DateTime.now();
  final fechas = prestamos
      .where((p) => p.saldo > 0.01)
      .map((p) => asProximoPagoFecha(p.proximoPago))
      .whereType<DateTime>()
      .toList();
  if (fechas.isEmpty) return null;

  final futuras = fechas.where((f) => !f.isBefore(hoy)).toList();
  if (futuras.isNotEmpty) {
    futuras.sort();
    return futuras.first;
  }
  fechas.sort();
  return fechas.first;
}
