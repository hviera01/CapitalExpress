/// Roles de usuario. "admin" y "cobrador" son los originales, iguales
/// a los que usa la app Kotlin (campo `rol` en la coleccion
/// `usuarios`). "desarrollador" es un rol nuevo con los MISMOS
/// permisos que admin en toda la app (ver esAdminOEquivalente) -- la
/// unica diferencia es quien recibe el push de tickets nuevos (ver
/// PushNotificationsService, que exige especificamente este rol, no
/// cualquier admin).
class Roles {
  Roles._();

  static const String admin = 'admin';
  static const String cobrador = 'cobrador';
  static const String desarrollador = 'desarrollador';

  /// En toda la app, "es admin" (ve todo, administra todo) significa
  /// admin O desarrollador -- usar esto en vez de comparar `rol ==
  /// Roles.admin` directo.
  static bool esAdminOEquivalente(String? rol) => rol == admin || rol == desarrollador;
}
