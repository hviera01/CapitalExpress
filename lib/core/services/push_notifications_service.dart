import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notificacion push cuando entra un ticket nuevo -- solo se activa
/// para usuarios admin (ver InactividadGuard, que llama a init() apenas
/// hay sesion admin iniciada). El token FCM de este dispositivo se
/// guarda en `fcmTokens/{token}`; la Cloud Function `avisarTicketNuevo`
/// (ver functions/index.js) le manda push a todos los tokens ahi
/// registrados cada vez que se crea un documento en `tickets`.
///
/// Solo aplica en Android y Web -- Windows no tiene soporte real de FCM
/// en este stack, se deja igual que siempre.
class PushNotificationsService {
  // Solo true una vez que el token realmente quedo guardado -- si el
  // permiso se nego (ej. iOS bloqueo el cartel por no venir de un tap
  // directo), NO se marca, para que un boton "Activar notificaciones"
  // pueda reintentar despues.
  static bool _tokenRegistrado = false;
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  static bool get aplica => kIsWeb || (!kIsWeb && Platform.isAndroid);

  /// Reemplazar con el "Web Push certificate" (VAPID key) del proyecto
  /// -- Firebase Console > Configuración del proyecto > Cloud Messaging
  /// > Certificados push web. Sin esto, el push en Web escritorio/movil
  /// no funciona (Android no lo necesita).
  static const _vapidKeyWeb =
      'BKAkUVkNCqw8Jn-Ekrmwqs3qoPIgLCDSFBoujMRpmgMx7K5SQEPbukMwi5Fm_q833U7CzQOlWGVcR9SYoGBZCXk';

  /// Llamar apenas hay sesion (ver InactividadGuard): funciona directo
  /// en Android/Chrome, pero en iOS Safari el permiso NO aparece si
  /// este pedido no viene de un tap directo del usuario -- ahi hace
  /// falta el boton explicito (ver CeBotonActivarPush) para que el tap
  /// mismo dispare requestPermission().
  static Future<void> init() async {
    if (!aplica || _tokenRegistrado) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final permiso = await messaging.requestPermission();
      if (permiso.authorizationStatus == AuthorizationStatus.denied) return;

      if (!kIsWeb) {
        await _localNotifications.initialize(
          const InitializationSettings(
            android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          ),
        );
      }

      final token = kIsWeb
          ? await messaging.getToken(vapidKey: _vapidKeyWeb)
          : await messaging.getToken();
      if (token == null || token.isEmpty) return;
      await _guardarToken(token);
      _tokenRegistrado = true;
      messaging.onTokenRefresh.listen(_guardarToken);

      FirebaseMessaging.onMessage.listen(_mostrarEnPrimerPlano);
    } catch (_) {
      // Nunca debe tumbar el arranque de la app -- el push es un
      // extra, no algo de lo que dependa poder usar el sistema.
    }
  }

  /// Estado actual del permiso SIN pedirlo (no dispara ningun cartel) --
  /// para decidir si mostrar el boton "Activar notificaciones".
  static Future<bool> permisoConcedido() async {
    if (!aplica) return true;
    try {
      final ajustes = await FirebaseMessaging.instance.getNotificationSettings();
      return ajustes.authorizationStatus == AuthorizationStatus.authorized ||
          ajustes.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _guardarToken(String? token) async {
    if (token == null || token.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('fcmTokens').doc(token).set({
        'plataforma': kIsWeb ? 'web' : 'android',
        'fechaActualizacion': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  static void _mostrarEnPrimerPlano(RemoteMessage mensaje) {
    // En Web el navegador ya se encarga (service worker); esto es solo
    // para Android con la app abierta, que si no se muestra a mano no
    // aparece ninguna notificacion (FCM solo la muestra sola cuando la
    // app esta en segundo plano/cerrada).
    if (kIsWeb) return;
    final notif = mensaje.notification;
    if (notif == null) return;
    _localNotifications.show(
      notif.hashCode,
      notif.title,
      notif.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'tickets',
          'Tickets',
          channelDescription: 'Avisos de tickets nuevos',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
