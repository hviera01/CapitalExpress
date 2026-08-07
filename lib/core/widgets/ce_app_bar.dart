import 'package:flutter/material.dart';

/// AppBar navy con subtitulo de color debajo del titulo (ADMIN PANEL /
/// PANEL DE COBRANZA en los mockups).
class CeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String titulo;
  final String subtitulo;
  final Color colorSubtitulo;
  final Widget? leading;
  final List<Widget> actions;

  const CeAppBar({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.colorSubtitulo,
    this.leading,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: leading,
      titleSpacing: leading == null ? 20 : 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            subtitulo,
            style: TextStyle(
              color: colorSubtitulo,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(64);
}
