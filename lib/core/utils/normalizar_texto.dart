/// Minusculas + sin acentos, para comparar texto de busqueda sin
/// importar mayusculas/tildes (equivalente simplificado de
/// BusquedaUtils.normalizarTexto en la app Kotlin original).
String normalizarTexto(String texto) {
  const conAcento = 'áéíóúÁÉÍÓÚñÑ';
  const sinAcento = 'aeiouAEIOUnN';
  var resultado = texto.toLowerCase().trim();
  for (var i = 0; i < conAcento.length; i++) {
    resultado = resultado.replaceAll(conAcento[i].toLowerCase(), sinAcento[i].toLowerCase());
  }
  return resultado;
}
