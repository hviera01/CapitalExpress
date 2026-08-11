/// Nombre de la empresa para textos de marca dentro de la app.
///
/// `corto` es el que se usa SOLO donde el sistema operativo/navegador
/// controla el espacio y recortaria el texto de todos modos (nombre del
/// icono instalado, pestaña del navegador, selector de apps recientes).
/// En el resto de lugares (login, encabezados, recibos, reportes) se usa
/// `corto` + `sufijoLegal` juntos -- ver MarcaLockup para el widget que
/// los combina en un lockup de dos tamaños.
class Marca {
  static const corto = 'SIEG';
  static const sufijoLegal = 'S. de R.L. de C.V.';
  static const completo = '$corto $sufijoLegal';
}
