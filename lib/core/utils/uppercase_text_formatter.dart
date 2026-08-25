import 'package:flutter/services.dart';

/// Convierte a MAYUSCULAS lo que se va escribiendo en un campo de
/// texto, sin mover el cursor. Usar SOLO en campos de texto libre
/// (nombres, direcciones, notas, etc.) -- NUNCA en codigo/contrasena de
/// login (son sensibles a mayus/minus contra lo ya guardado en
/// Firestore) ni en campos de email.
class UpperCaseTextFormatter extends TextInputFormatter {
  const UpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

const upperCaseTextFormatter = UpperCaseTextFormatter();
