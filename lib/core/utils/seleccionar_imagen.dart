import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Muestra un bottom sheet Camara/Galeria y devuelve los bytes de la foto
/// elegida (ya comprimida), o null si el usuario cancela.
Future<Uint8List?> seleccionarImagen(BuildContext context) async {
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
            title: const Text('Elegir de galeria'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );

  if (origen == null) return null;

  return seleccionarImagenDeFuente(origen);
}

Future<Uint8List?> seleccionarImagenDeFuente(ImageSource origen) async {
  final picker = ImagePicker();
  final archivo = await picker.pickImage(
    source: origen,
    maxWidth: 1600,
    imageQuality: 80,
  );
  if (archivo == null) return null;

  return archivo.readAsBytes();
}
