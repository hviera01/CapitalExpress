import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Card con la sombra "ambient" del SIEG Design System
/// (0px 4px 20px rgba(10,25,47,0.05)) en vez de la elevacion Material
/// por defecto, para calzar exactamente con los mockups.
class CeCard extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color? borderColor;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;

  const CeCard({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.borderColor = CEColors.border,
    this.onTap,
    this.padding = const EdgeInsets.all(20),
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(radius),
            border: borderColor != null ? Border.all(color: borderColor!) : null,
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D0A192F),
                blurRadius: 20,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
