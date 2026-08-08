import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Una pestaña abierta en escritorio Web (ver CeWebShell). El
/// `contenido` se construye UNA sola vez, al abrir la pestaña, y
/// queda vivo en memoria mientras la pestaña siga abierta -- por eso
/// cambiar de pestaña es instantaneo (no hay que recargar nada, es la
/// MISMA instancia del widget/State de siempre).
class WebTabItem {
  final String id;
  final String titulo;
  final IconData icono;
  final Widget contenido;
  final bool cerrable;

  const WebTabItem({
    required this.id,
    required this.titulo,
    required this.icono,
    required this.contenido,
    this.cerrable = true,
  });
}

class WebTabsState {
  final List<WebTabItem> tabs;
  final int indiceActivo;

  const WebTabsState({this.tabs = const [], this.indiceActivo = 0});
}

/// Mismo patron que Super Color/Variedades Lopsi (ver app_shell.dart de
/// esos proyectos): abrir una seccion ya abierta antes solo cambia el
/// indice activo (no crea una pestaña duplicada ni reconstruye nada);
/// las pestañas quedan vivas hasta que se cierran a mano o se cierra
/// sesion.
class WebTabsNotifier extends Notifier<WebTabsState> {
  @override
  WebTabsState build() => const WebTabsState();

  void abrir(WebTabItem tab) {
    final existente = state.tabs.indexWhere((t) => t.id == tab.id);
    if (existente != -1) {
      state = WebTabsState(tabs: state.tabs, indiceActivo: existente);
      return;
    }
    final nuevos = [...state.tabs, tab];
    state = WebTabsState(tabs: nuevos, indiceActivo: nuevos.length - 1);
  }

  void seleccionar(int index) {
    if (index < 0 || index >= state.tabs.length) return;
    state = WebTabsState(tabs: state.tabs, indiceActivo: index);
  }

  void cerrar(String id) {
    final idx = state.tabs.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final nuevos = [...state.tabs]..removeAt(idx);
    var nuevoIndice = state.indiceActivo;
    if (nuevos.isEmpty) {
      nuevoIndice = 0;
    } else if (idx < state.indiceActivo) {
      nuevoIndice -= 1;
    } else if (idx == state.indiceActivo) {
      nuevoIndice = nuevoIndice.clamp(0, nuevos.length - 1);
    }
    state = WebTabsState(tabs: nuevos, indiceActivo: nuevoIndice);
  }

  /// Al cerrar sesion: nada de esto debe sobrevivir a un cambio de
  /// usuario (ver InactividadGuard/authProvider).
  void limpiar() => state = const WebTabsState();
}

final webTabsProvider = NotifierProvider<WebTabsNotifier, WebTabsState>(WebTabsNotifier.new);
