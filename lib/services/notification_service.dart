import 'dart:developer' as developer;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:flutter_application_1/config/router/app_router.dart';

// Debe coincidir EXACTAMENTE con el topic usado en la Cloud Function
// sincronizarYAlertar (functions/index.js).
const String _topicoAlertas = 'alertas_urgencias';

const String _canalAlertasId = 'alertas_calidad_aire';
const String _canalAlertasNombre = 'Alertas de calidad del aire';
const String _canalAlertasDescripcion =
    'Notificaciones cuando una variable supera el umbral de alarma';

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

/// Maneja mensajes recibidos cuando la app está cerrada o en segundo plano.
/// DEBE ser una función de nivel superior (no un método de clase) y llevar
/// esta anotación exacta, o Firebase no podrá invocarla correctamente.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  developer.log('Notificación recibida en segundo plano: ${message.messageId}');
  // No es necesario mostrar nada manualmente aquí: si el mensaje incluye
  // un bloque "notification" (como el que envía la Cloud Function), el
  // sistema operativo ya la muestra automáticamente en la bandeja.
}

class NotificationService {
  static final NotificationService _instancia = NotificationService._interno();
  factory NotificationService() => _instancia;
  NotificationService._interno();

  Future<void> inicializar() async {
    // 1. Pedir permiso al usuario (obligatorio en iOS y Android 13+)
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    developer.log('Permiso de notificaciones: ${settings.authorizationStatus}');

    // 2. Configurar el canal de notificaciones local (necesario en Android
    // para mostrar la alerta mientras la app está abierta en primer plano)
    const canalAndroid = AndroidNotificationChannel(
      _canalAlertasId,
      _canalAlertasNombre,
      description: _canalAlertasDescripcion,
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(canalAndroid);

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (respuesta) => _alTocarNotificacion(),
    );

    // 3. Suscribirse al mismo tópico que usa la Cloud Function
    await FirebaseMessaging.instance.subscribeToTopic(_topicoAlertas);
    developer.log('Suscrito al tópico: $_topicoAlertas');

    // 4. Mostrar la notificación manualmente cuando llega con la app
    // ABIERTA en primer plano (FCM no la muestra por sí solo en ese caso)
    FirebaseMessaging.onMessage.listen(_mostrarNotificacionLocal);

    // 5. Manejar el toque en la notificación cuando la app estaba en
    // segundo plano (no cerrada por completo)
    FirebaseMessaging.onMessageOpenedApp.listen((_) => _alTocarNotificacion());

    // 6. Si la app se abrió directamente desde una notificación (estaba
    // completamente cerrada), revisarlo al iniciar
    final mensajeInicial = await FirebaseMessaging.instance.getInitialMessage();
    if (mensajeInicial != null) {
      _alTocarNotificacion();
    }
  }

  void _mostrarNotificacionLocal(RemoteMessage mensaje) {
    final notificacion = mensaje.notification;
    if (notificacion == null) return;

    _localNotifications.show(
      notificacion.hashCode,
      notificacion.title,
      notificacion.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _canalAlertasId,
          _canalAlertasNombre,
          channelDescription: _canalAlertasDescripcion,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  void _alTocarNotificacion() {
    // Lleva al usuario directo a la pantalla de gráficas al tocar la alerta
    appRouter.go('/graficas');
  }
}