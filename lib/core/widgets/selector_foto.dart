import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/seleccionar_imagen.dart';
import 'imagen_red_network.dart';

/// Un slot de foto reusable: muestra la foto ya subida (por URL) o la
/// recien elegida (bytes locales, aun sin subir), con boton para
/// seleccionar/reemplazar. La subida real la hace el formulario dueno al
/// guardar (no aca), para no subir fotos descartadas si el usuario cancela.
class SelectorFoto extends StatelessWidget {
  final String label;
  final String urlActual;
  final Uint8List? bytesNuevos;
  final ValueChanged<Uint8List> onSeleccionar;

  const SelectorFoto({
    super.key,
    required this.label,
    required this.urlActual,
    required this.onSeleccionar,
    this.bytesNuevos,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final bytes = await seleccionarImagen(context);
        if (bytes != null) onSeleccionar(bytes);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: CEColors.textSecondary)),
          const SizedBox(height: 6),
          AspectRatio(
            aspectRatio: 1,
            child: bytesNuevos != null
                ? Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: CEColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.memory(bytesNuevos!, fit: BoxFit.cover),
                  )
                : urlActual.isNotEmpty
                    ? ImagenRedNetwork(url: urlActual)
                    : Container(
                        decoration: BoxDecoration(
                          color: CEColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: CEColors.border, style: BorderStyle.solid),
                        ),
                        child: const Center(
                          child: Icon(Icons.add_a_photo_outlined, color: CEColors.textSecondary),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
