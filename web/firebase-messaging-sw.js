// Service worker de notificaciones push en Web (segundo plano/pestaña
// cerrada) -- ver lib/core/services/push_notifications_service.dart.
// Mismos datos que lib/firebase_options.dart (configuracion Web).
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCKrOaJP8cyApDju7pEnhsmpHDL1mlEsgg',
  authDomain: 'capitalexpressapp-c03c5.firebaseapp.com',
  projectId: 'capitalexpressapp-c03c5',
  storageBucket: 'capitalexpressapp-c03c5.firebasestorage.app',
  messagingSenderId: '583284933861',
  appId: '1:583284933861:web:16825cac3ec25058a4800c',
});

firebase.messaging();
