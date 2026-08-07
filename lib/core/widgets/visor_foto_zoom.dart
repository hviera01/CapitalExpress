import 'package:flutter/material.dart';

import 'imagen_red_network.dart';

/// Abre una foto a pantalla completa con pinch-to-zoom.
void abrirFotoZoom(BuildContext context, String url) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (context, _, _) => _VisorFotoZoom(url: url),
    ),
  );
}

class _VisorFotoZoom extends StatelessWidget {
  final String url;

  const _VisorFotoZoom({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: ImagenRedNetwork(url: url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
