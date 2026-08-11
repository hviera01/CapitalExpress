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

/// Coincidencia de busqueda por palabras: TODAS las palabras de
/// `query` tienen que aparecer en `texto` (normalizado), no importa el
/// orden ni si hay otras palabras en el medio -- asi buscar "Henry
/// Viera" encuentra a "Henry Jose Viera" sin que el nombre intermedio
/// rompa la coincidencia (antes era un `contains` literal de todo el
/// texto seguido, que exigia que las palabras fueran contiguas).
bool coincideBusqueda(String texto, String query) {
  final t = normalizarTexto(texto);
  final palabras = normalizarTexto(query).split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  return palabras.every((p) => t.contains(p));
}
