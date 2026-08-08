import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'ce_card.dart';

/// Piezas del panel principal ("dashboard") de escritorio Web -- ver
/// AdminHomeScreen/CobradorHomeScreen._cuerpoEscritorio.

/// Encabezado: saludo a la izquierda, un valor grande destacado a la
/// derecha (ej. valor de cartera).
class CeDashboardHeader extends StatelessWidget {
  final String saludo;
  final String subtitulo;
  final String? etiquetaValor;
  final String? valor;

  const CeDashboardHeader({
    super.key,
    required this.saludo,
    required this.subtitulo,
    this.etiquetaValor,
    this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(saludo,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, color: CEColors.textPrimary)),
              const SizedBox(height: 4),
              Text(subtitulo, style: const TextStyle(fontSize: 13, color: CEColors.textSecondary)),
            ],
          ),
        ),
        if (valor != null) ...[
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(etiquetaValor ?? '',
                  style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: CEColors.textSecondary,
                      letterSpacing: 0.5)),
              const SizedBox(height: 2),
              Text(valor!,
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w800, color: CEColors.primary)),
            ],
          ),
        ],
      ],
    );
  }
}

/// Boton de accion rapida chico: circulo con icono arriba, etiqueta
/// abajo -- para la fila "Acciones rapidas" del dashboard.
class CeAccionRapidaTile extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final Color color;
  final VoidCallback onTap;

  const CeAccionRapidaTile({
    super.key,
    required this.icono,
    required this.titulo,
    required this.onTap,
    this.color = CEColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      child: CeCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icono, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(titulo,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: CEColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de "explorar" (Solicitudes/Ver Clientes/etc.): icono tenue
/// arriba a la derecha, titulo, valor+subtitulo y un link abajo.
class CeTarjetaExplorar extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String valor;
  final String subtitulo;
  final String enlace;
  final VoidCallback onTap;

  const CeTarjetaExplorar({
    super.key,
    required this.icono,
    required this.titulo,
    required this.valor,
    required this.subtitulo,
    required this.enlace,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CeCard(
      onTap: onTap,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: Icon(icono, size: 34, color: CEColors.border),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo,
                  style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w800, color: CEColors.textPrimary)),
              const SizedBox(height: 8),
              Text(valor,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800, color: CEColors.textPrimary)),
              const SizedBox(height: 2),
              Text(subtitulo, style: const TextStyle(fontSize: 11.5, color: CEColors.textSecondary)),
              const SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(enlace,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, color: CEColors.accent)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward, size: 13, color: CEColors.accent),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tarjeta destacada azul (ej. "Cobrado hoy").
class CeTarjetaDestacada extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final String? nota;

  const CeTarjetaDestacada({super.key, required this.etiqueta, required this.valor, this.nota});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CEColors.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x1A0A192F), blurRadius: 20, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(etiqueta.toUpperCase(),
              style: const TextStyle(
                  color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
          const SizedBox(height: 8),
          Text(valor,
              style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
          if (nota != null) ...[
            const SizedBox(height: 6),
            Text(nota!, style: const TextStyle(color: Colors.white60, fontSize: 11.5)),
          ],
        ],
      ),
    );
  }
}

/// Fila de un evento en "Actividad reciente".
class CeActividadItem extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String titulo;
  final String subtitulo;
  final String tiempo;

  const CeActividadItem({
    super.key,
    required this.icono,
    required this.color,
    required this.titulo,
    required this.subtitulo,
    required this.tiempo,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icono, size: 15, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: CEColors.textPrimary)),
                const SizedBox(height: 1),
                Text(subtitulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: CEColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(tiempo, style: const TextStyle(fontSize: 10.5, color: CEColors.textSecondary)),
        ],
      ),
    );
  }
}

/// Panel blanco ("Actividad reciente"): titulo + lista de
/// [CeActividadItem] + link "Ver todo" opcional.
class CePanelActividad extends StatelessWidget {
  final String titulo;
  final List<Widget> items;
  final VoidCallback? onVerTodo;
  final VoidCallback? onRefrescar;

  const CePanelActividad({
    super.key,
    required this.titulo,
    required this.items,
    this.onVerTodo,
    this.onRefrescar,
  });

  @override
  Widget build(BuildContext context) {
    return CeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(titulo.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: CEColors.textSecondary,
                        letterSpacing: 0.5)),
              ),
              if (onRefrescar != null)
                InkWell(
                  onTap: onRefrescar,
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.refresh, size: 16, color: CEColors.textSecondary),
                  ),
                ),
            ],
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('Sin actividad reciente',
                    style: TextStyle(fontSize: 12, color: CEColors.textSecondary)),
              ),
            )
          else
            ...items,
          if (onVerTodo != null) ...[
            const Divider(height: 20),
            InkWell(
              onTap: onVerTodo,
              child: const Center(
                child: Text('Ver historial completo',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: CEColors.accent)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "hace 5 min" / "hace 2 h" / "hace 3 d" -- version corta en
/// español para la actividad reciente.
String tiempoRelativoCorto(DateTime fecha) {
  final diferencia = DateTime.now().difference(fecha);
  if (diferencia.inMinutes < 1) return 'ahora';
  if (diferencia.inMinutes < 60) return 'hace ${diferencia.inMinutes} min';
  if (diferencia.inHours < 24) return 'hace ${diferencia.inHours} h';
  return 'hace ${diferencia.inDays} d';
}
