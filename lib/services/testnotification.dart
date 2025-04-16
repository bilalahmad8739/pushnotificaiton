import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

class NotificationHelper {
  static final _notification = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notification.initialize(initSettings);

    const androidChannel = AndroidNotificationChannel(
      'important_notification', // ID
      'My Channel',             // Name
      importance: Importance.max,
    );

    final androidPlugin =
        _notification.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(androidChannel);

    tz.initializeTimeZones();
  }

  static Future<void> scheduleNotification(
    String title,
    String body,
    int secondsFromNow,
  ) async {
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    const androidDetails = AndroidNotificationDetails(
      'important_notification',
      'My Channel',
      importance: Importance.max,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await _notification.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.now(tz.local).add(Duration(seconds: secondsFromNow)),
      notificationDetails,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: null,
    );
  }

  static Future<void> cancelAllNotifications() async {
    await _notification.cancelAll();
  }
}
