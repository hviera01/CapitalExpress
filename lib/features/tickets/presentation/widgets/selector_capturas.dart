import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/seleccionar_imagen.dart';

/// Hasta [maximo] capturas/fotos adjuntas a un ticket. Reusa
/// seleccionarImagenDeFuente (misma compresion que las fotos de
/// cliente: maxWidth 1600, calidad 80) para que los adjuntos sean
/// livianos y la subida sea rapida.
class SelectorCapturas extends StatelessWidget {
  final List<Uint8List> fotos;
  final ValueChanged<List<Uint8List>> onCambiar;
  final int maximo;

  const SelectorCapturas({
    super.key,
    required this.fotos,
    required this.onCambiar,
    this.maximo = 3,
  });

  Future<void> _agregar(BuildContext context) async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (origen == null) return;
    final bytes = await seleccionarImagenDeFuente(origen);
    if (bytes != null) onCambiar([...fotos, bytes]);
  }

  void _quitar(int indice) {
    final nuevas = [...fotos]..removeAt(indice);
    onCambiar(nuevas);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var i = 0; i < fotos.length; i++)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(fotos[i], width: 84, height: 84, fit: BoxFit.cover),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: InkWell(
                  onTap: () => _quitar(i),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: CEColors.danger, shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 13, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        if (fotos.length < maximo)
          InkWell(
            onTap: () => _agregar(context),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: CEColors.border),
                color: CEColors.surface,
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, size: 20, color: CEColors.textSecondary),
                  SizedBox(height: 4),
                  Text('Agregar', style: TextStyle(fontSize: 10, color: CEColors.textSecondary)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
