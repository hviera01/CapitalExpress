import 'package:flutter/material.dart';

import '../services/actualizacion_service.dart';
import '../theme/app_theme.dart';
import '../version_app.dart';

/// Dialogo central que avisa que hay una version nueva publicada. Se
/// abre solo (al iniciar sesion) o a mano desde "Buscar actualizaciones"
/// en el menu lateral. "Despues" solo cierra el dialogo: no queda nada
/// guardado, asi que la proxima vez vuelve a preguntar si la instalada
/// sigue sin ser la mas nueva.
Future<void> mostrarDialogoActualizacion(
  BuildContext context,
  ActualizacionDisponible actualizacion,
) {
  return showDialog(
    context: context,
    builder: (context) => PopScope(
      canPop: false,
      child: _ActualizacionDialog(actualizacion: actualizacion),
    ),
  );
}

class _ActualizacionDialog extends StatefulWidget {
  final ActualizacionDisponible actualizacion;
  const _ActualizacionDialog({required this.actualizacion});

  @override
  State<_ActualizacionDialog> createState() => _ActualizacionDialogState();
}

class _ActualizacionDialogState extends State<_ActualizacionDialog> {
  bool _descargando = false;
  double _progreso = 0;
  String? _error;

  Future<void> _actualizar() async {
    setState(() {
      _descargando = true;
      _error = null;
    });
    try {
      await ActualizacionService.descargarEInstalar(
        widget.actualizacion,
        (p) {
          if (mounted) setState(() => _progreso = p);
        },
      );
      // Si el await termina y seguimos aca, algo fallo: en Windows
      // descargarEInstalar cierra la app apenas el instalador queda
      // lanzado; en Android abre el instalador y sigue corriendo.
      if (mounted) setState(() => _descargando = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _descargando = false;
        _error = 'No se pudo descargar la actualización. Probá de nuevo más tarde.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Actualización disponible', style: TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hay una nueva versión (v${widget.actualizacion.version}) disponible para instalar.',
                style: const TextStyle(fontSize: 13.5)),
            const SizedBox(height: 4),
            Text('Tenés instalada la versión v$versionApp.',
                style: const TextStyle(fontSize: 12, color: CEColors.textSecondary)),
            if (widget.actualizacion.notas.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(widget.actualizacion.notas,
                  style: const TextStyle(fontSize: 12.5, color: CEColors.textSecondary)),
            ],
            if (_descargando) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progreso > 0 ? _progreso : null),
              const SizedBox(height: 6),
              const Text('Descargando...', style: TextStyle(fontSize: 11.5, color: CEColors.textSecondary)),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(fontSize: 12, color: CEColors.danger)),
            ],
          ],
        ),
      ),
      actions: _descargando
          ? const []
          : [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Después')),
              ElevatedButton(onPressed: _actualizar, child: const Text('Actualizar ahora')),
            ],
    );
  }
}
