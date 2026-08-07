import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme/app_theme.dart';

/// Imagen cargada por HTTP con timeout y reintentos manuales.
///
/// `Image.network` no tiene timeout: si la conexion se cuelga (comun en
/// Windows/desktop con redes lentas) el widget queda "cargando" para
/// siempre sin mostrar error ni fallback. Aca se hace el fetch a mano con
/// `http.get(...).timeout(...)`, reintentando con backoff, y si todo falla
/// se muestra un icono reintentable con el error real en un tooltip.
class ImagenRedNetwork extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const ImagenRedNetwork({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  static final http.Client _client = http.Client();

  /// Cache en memoria por URL: sin esto, la misma foto (a veces ~2MB) se
  /// vuelve a descargar entera cada vez que el widget se monta de nuevo
  /// (lista -> detalle -> volver a la lista, etc), que es la razon
  /// principal por la que las fotos se sienten lentas en toda la app.
  static final Map<String, Uint8List> _cache = {};

  @override
  State<ImagenRedNetwork> createState() => _ImagenRedNetworkState();
}

class _ImagenRedNetworkState extends State<ImagenRedNetwork> {
  Uint8List? _bytes;
  String? _error;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(covariant ImagenRedNetwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _bytes = null;
      _error = null;
      _cargar();
    }
  }

  Future<void> _cargar() async {
    if (widget.url.isEmpty) {
      setState(() {
        _cargando = false;
        _error = 'Sin foto';
      });
      return;
    }

    final cacheada = ImagenRedNetwork._cache[widget.url];
    if (cacheada != null) {
      setState(() {
        _bytes = cacheada;
        _cargando = false;
      });
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });

    const intentos = 4;
    for (var i = 0; i < intentos; i++) {
      try {
        final resp = await ImagenRedNetwork._client
            .get(Uri.parse(widget.url))
            .timeout(const Duration(seconds: 15));
        if (resp.statusCode == 200) {
          ImagenRedNetwork._cache[widget.url] = resp.bodyBytes;
          if (!mounted) return;
          setState(() {
            _bytes = resp.bodyBytes;
            _cargando = false;
          });
          return;
        }
        _error = 'HTTP ${resp.statusCode}';
      } on TimeoutException {
        _error = 'Tiempo de espera agotado';
      } on SocketException catch (e) {
        _error = 'Sin conexion (${e.osError?.message ?? e.message})';
      } catch (e) {
        _error = e.toString();
      }
      if (i < intentos - 1) {
        await Future.delayed(Duration(seconds: 2 * (i + 1)));
      }
    }

    if (!mounted) return;
    setState(() => _cargando = false);
  }

  @override
  Widget build(BuildContext context) {
    Widget contenido;

    if (_cargando) {
      contenido = const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else if (_bytes != null) {
      // cacheWidth/Height le pide al decoder que baje la resolucion a lo
      // que realmente se va a mostrar (las fotos originales pesan ~2MB a
      // resolucion completa) -- decodifica y pinta mucho mas rapido que
      // decodificar entero y recien despues escalar visualmente.
      final dpr = MediaQuery.devicePixelRatioOf(context);
      contenido = Image.memory(
        _bytes!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        cacheWidth: widget.width != null ? (widget.width! * dpr).round() : null,
        cacheHeight: widget.height != null ? (widget.height! * dpr).round() : null,
      );
    } else {
      contenido = Tooltip(
        message: _error ?? 'Error desconocido',
        child: InkWell(
          onTap: _cargar,
          child: const Center(
            child: Icon(Icons.refresh, color: CEColors.textSecondary),
          ),
        ),
      );
    }

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: CEColors.surface,
        borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
        border: Border.all(color: CEColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: contenido,
    );
  }
}
