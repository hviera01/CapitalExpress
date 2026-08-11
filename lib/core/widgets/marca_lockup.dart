import 'package:flutter/material.dart';

import '../constants/marca.dart';

/// "Lockup" de marca: nombre corto grande/negrita + sufijo legal chico y
/// mas tenue (nunca se corta -- se achica solo con FittedBox si el
/// espacio disponible es menor al del texto). `direction` vertical
/// (apilado) sirve para topbar/drawer/login; horizontal (en la misma
/// linea) para donde ya hay una segunda linea propia debajo (ej. el
/// subtitulo de CeAppBar).
class MarcaLockup extends StatelessWidget {
  final Color color;
  final double fontSizeNombre;
  final double fontSizeSufijo;
  final FontWeight pesoNombre;
  final double letterSpacing;
  final Axis direction;
  final CrossAxisAlignment alineacion;

  const MarcaLockup({
    super.key,
    this.color = Colors.white,
    this.fontSizeNombre = 20,
    this.fontSizeSufijo = 10,
    this.pesoNombre = FontWeight.w800,
    this.letterSpacing = 1,
    this.direction = Axis.vertical,
    this.alineacion = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final nombre = Text(
      Marca.corto,
      style: TextStyle(
        color: color,
        fontSize: fontSizeNombre,
        fontWeight: pesoNombre,
        letterSpacing: letterSpacing,
        height: 1,
      ),
    );
    final sufijo = Text(
      Marca.sufijoLegal,
      style: TextStyle(
        color: color.withValues(alpha: 0.68),
        fontSize: fontSizeSufijo,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        height: 1,
      ),
    );

    final contenido = direction == Axis.vertical
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: alineacion,
            children: [nombre, const SizedBox(height: 2), sufijo],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [nombre, const SizedBox(width: 6), sufijo],
          );

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alineacion == CrossAxisAlignment.start
          ? Alignment.centerLeft
          : Alignment.center,
      child: contenido,
    );
  }
}
