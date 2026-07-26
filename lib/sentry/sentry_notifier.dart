// sentry_notifier.dart - Canal propio del Centinela.
// API v22 de flutter_local_notifications (parametros nombrados), identica a
// la que ya usa main.dart. El permiso de notificaciones ya lo pide la app.

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class SentryNotifier {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _inited = false;

  static Future<void> _init() async {
    if (_inited) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
        settings: const InitializationSettings(android: androidInit));
    _inited = true;
  }

  static Future<void> show(String title, String body,
      {bool critical = false}) async {
    await _init();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'sentry_events',
        'Modo Centinela',
        channelDescription: 'Alertas del Modo Centinela',
        importance: critical ? Importance.max : Importance.defaultImportance,
        priority: critical ? Priority.high : Priority.defaultPriority,
        category: critical ? AndroidNotificationCategory.alarm : null,
      ),
    );
    final id = DateTime.now().millisecondsSinceEpoch % 100000;
    await _plugin.show(
        id: id, title: title, body: body, notificationDetails: details);
  }
}
