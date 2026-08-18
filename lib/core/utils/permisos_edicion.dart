import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/clientes/presentation/screens/cliente_form_screen.dart';
import '../../features/prestamos/presentation/screens/editar_prestamo_screen.dart';
import '../../features/solicitudes/providers/solicitud_edicion_provider.dart';
import '../constants/roles.dart';
import '../models/cliente_model.dart';
import '../models/prestamo_model.dart';
import '../widgets/ce_web_nav.dart';

/// Politica central de "ventana de 1 hora": admin/desarrollador siempre
/// pueden editar libre; un cobrador solo puede editar libre durante la
/// primera hora desde que se creo la entidad -- pasada esa hora hace
/// falta una solicitud de edicion aprobada (ver
/// SolicitudEdicionRepository.permisoActivoPara).
bool puedeEditarLibre(String? rol, Timestamp? fechaCreacion) {
  if (Roles.esAdminOEquivalente(rol)) return true;
  if (fechaCreacion == null) return false;
  return DateTime.now().difference(fechaCreacion.toDate()) < const Duration(hours: 1);
}

/// Resuelve la politica de edicion de un cliente y navega al lugar
/// correcto: formulario normal (libre o con permiso otorgado, en cuyo
/// caso llega precargado con los valores propuestos) o al mismo
/// formulario en "modo solicitud" si hay que pedir permiso primero.
/// Reemplaza las llamadas directas a `ClienteFormScreen` para EDITAR
/// (crear cliente nuevo no pasa por aca, no tiene restriccion).
Future<void> abrirEdicionCliente(BuildContext context, WidgetRef ref, ClienteModel c) async {
  final usuario = ref.read(authProvider).usuario;
  if (puedeEditarLibre(usuario?.rol, c.fechaCreacion)) {
    // Edicion libre normal: la ruta '/clientes/:id/editar' ya reconstruye
    // este mismo ClienteFormScreen(clienteId, clienteInicial) en su
    // GoRoute (ver app_router.dart) a partir de `extra`, asi que
    // irAPantalla es seguro aca -- en mobile navega por esa ruta, en
    // escritorio Web usa el widget de aca directo, y ambos coinciden.
    await irAPantalla(context,
        ruta: '/clientes/${c.id}/editar',
        extra: c,
        pantalla: ClienteFormScreen(clienteId: c.id, clienteInicial: c));
    return;
  }

  // A partir de aca la pantalla necesita parametros (modoSolicitud /
  // valoresPropuestos / solicitudEdicionId) que la ruta de go_router NO
  // conoce (su builder solo recibe el ClienteModel por `extra`) -- en
  // mobile, `irAPantalla` navegaria por esa ruta e IGNORARIA estos
  // parametros. Por eso aca se hace Navigator.push directo, en todas
  // las plataformas, para garantizar que se abra exactamente esta
  // instancia del widget.
  final permiso = await ref.read(solicitudEdicionRepositoryProvider).permisoActivoPara(c.id);
  if (!context.mounted) return;
  final pantalla = permiso != null
      ? ClienteFormScreen(
          clienteId: c.id,
          clienteInicial: c,
          valoresPropuestos: permiso.valoresNuevos,
          solicitudEdicionId: permiso.id,
        )
      : ClienteFormScreen(clienteId: c.id, clienteInicial: c, modoSolicitud: true);
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));
}

/// Equivalente a [abrirEdicionCliente] para prestamos.
Future<void> abrirEdicionPrestamo(BuildContext context, WidgetRef ref, PrestamoModel p) async {
  final usuario = ref.read(authProvider).usuario;
  if (puedeEditarLibre(usuario?.rol, p.fechaCreacion)) {
    await irAPantalla(context,
        ruta: '/prestamos/${p.prestamoId}/editar',
        extra: p,
        pantalla: EditarPrestamoScreen(prestamoId: p.prestamoId, prestamoInicial: p));
    return;
  }

  // Ver comentario equivalente en abrirEdicionCliente: de aca en
  // adelante hace falta Navigator.push directo, no irAPantalla, porque
  // la ruta de go_router no conoce estos parametros extra.
  final permiso = await ref.read(solicitudEdicionRepositoryProvider).permisoActivoPara(p.prestamoId);
  if (!context.mounted) return;
  final pantalla = permiso != null
      ? EditarPrestamoScreen(
          prestamoId: p.prestamoId,
          prestamoInicial: p,
          valoresPropuestos: permiso.valoresNuevos,
          solicitudEdicionId: permiso.id,
        )
      : EditarPrestamoScreen(prestamoId: p.prestamoId, prestamoInicial: p, modoSolicitud: true);
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));
}
