import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CeSectionLabel extends StatelessWidget {
  final String texto;

  const CeSectionLabel(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Text(
        texto.toUpperCase(),
        style: const TextStyle(
          color: CEColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
