import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/app_theme.dart';
import '../utils/seleccionar_imagen.dart';
import 'imagen_red_network.dart';

/// Slot de foto con el mismo patron que "Crear Nuevo Cliente": icono +
/// etiqueta arriba, caja punteada con la foto (o "Sin foto"), y dos
/// botones Galeria/Camara debajo.
class SelectorFoto extends StatelessWidget {
  final IconData icono;
  final String label;
  final String urlActual;
  final Uint8List? bytesNuevos;
  final ValueChanged<Uint8List> onSeleccionar;

  const SelectorFoto({
    super.key,
    required this.icono,
    required this.label,
    required this.urlActual,
    required this.onSeleccionar,
    this.bytesNuevos,
  });

  Future<void> _elegir(BuildContext context, ImageSource origen) async {
    final bytes = await seleccionarImagenDeFuente(origen);
    if (bytes != null) onSeleccionar(bytes);
  }

  @override
  Widget build(BuildContext context) {
    final tieneFoto = bytesNuevos != null || urlActual.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icono, size: 16, color: CEColors.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 16 / 10,
          child: Container(
            decoration: BoxDecoration(
              color: CEColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: CEColors.border,
                style: tieneFoto ? BorderStyle.solid : BorderStyle.solid,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: bytesNuevos != null
                ? Image.memory(bytesNuevos!, fit: BoxFit.cover)
                : urlActual.isNotEmpty
                    ? ImagenRedNetwork(url: urlActual)
                    : const Center(
                        child: Text('Sin foto',
                            style: TextStyle(color: CEColors.textSecondary, fontSize: 12)),
                      ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _elegir(context, ImageSource.gallery),
                icon: const Icon(Icons.image_outlined, size: 16),
                label: const Text('Galería', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _elegir(context, ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined, size: 16),
                label: const Text('Cámara', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
