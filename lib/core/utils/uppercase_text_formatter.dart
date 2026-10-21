import 'package:flutter/services.dart';

/// Convierte a MAYUSCULAS lo que se va escribiendo en un campo de
/// texto, sin mover el cursor. Usar SOLO en campos de texto libre
/// (nombres, direcciones, notas, etc.) -- NUNCA en codigo/contrasena de
/// login (son sensibles a mayus/minus contra lo ya guardado en
/// Firestore) ni en campos de email.
///
/// Si el texto ya esta en mayusculas no se toca el valor (evita pelear
/// con el teclado del telefono mientras compone una palabra); si el
/// largo cambia (ej. la ß) se resetea la zona de composicion.
class UpperCaseTextFormatter extends TextInputFormatter {
  const UpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final mayus = newValue.text.toUpperCase();
    if (mayus == newValue.text) return newValue;
    if (mayus.length == newValue.text.length) {
      return newValue.copyWith(text: mayus);
    }
    final offset = newValue.selection.baseOffset.clamp(0, mayus.length);
    return TextEditingValue(
      text: mayus,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

const upperCaseTextFormatter = UpperCaseTextFormatter();
