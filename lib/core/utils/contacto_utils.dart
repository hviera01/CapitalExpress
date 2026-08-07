import 'package:url_launcher/url_launcher.dart';

String _soloDigitos(String telefono) => telefono.replaceAll(RegExp(r'[^0-9]'), '');

Future<void> llamarTelefono(String telefono) async {
  final numero = _soloDigitos(telefono);
  if (numero.isEmpty) return;
  await launchUrl(Uri.parse('tel:$numero'));
}

/// Honduras (+504) por defecto si el numero no trae codigo de pais.
Future<void> abrirWhatsapp(String telefono, {String? mensaje}) async {
  var numero = _soloDigitos(telefono);
  if (numero.isEmpty) return;
  if (numero.length <= 8) numero = '504$numero';
  final query = mensaje != null ? '?text=${Uri.encodeComponent(mensaje)}' : '';
  await launchUrl(
    Uri.parse('https://wa.me/$numero$query'),
    mode: LaunchMode.externalApplication,
  );
}
