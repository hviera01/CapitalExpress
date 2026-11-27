abstract final class TxtR {
  static const verbo = 'readecuar';
  static const verboMay = 'Readecuar';
  static const verboUp = 'READECUAR';
  static const part = 'readecuado';
  static const partMay = 'Readecuado';
  static const partUp = 'READECUADO';
  static const sust = 'readecuación';
  static const sustMay = 'Readecuación';
  static const sustUp = 'READECUACIÓN';
  static const pasado = 'readecuó';
  static const gerundioMay = 'Readecuando';
}

String textoEstadoPrestamo(String estado) =>
    estado == 'reestructurado' ? TxtR.partUp : estado.toUpperCase();
