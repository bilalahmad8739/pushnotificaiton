import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // Handle background notification tap
  print('Notification tapped in background: ${notificationResponse.id}');
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  static final AndroidNotificationDetails _androidNotificationDetails =
      AndroidNotificationDetails(
    'notification_channel_id',
    'Notifications',
    channelDescription: 'For all notifications',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
    visibility: NotificationVisibility.public,
    playSound: true,
    enableLights: true,
    enableVibration: true,
    fullScreenIntent: true,
    category: AndroidNotificationCategory.alarm,
    ongoing: false, // Not ongoing
    autoCancel: true, // Auto cancel when tapped
  );

  static const DarwinNotificationDetails _iOSNotificationDetails =
      DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

  static final NotificationDetails _notificationDetails = NotificationDetails(
    android: _androidNotificationDetails,
    iOS: _iOSNotificationDetails,
  );

  Future<void> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    print('🔔 Notification permission status: $status');
  }

  Future<void> requestPermissions() async {
    final plugin = FlutterLocalNotificationsPlugin();

    if (Platform.isIOS) {
      // iOS-specific permission request
      await plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
            critical: true, // For critical alerts that bypass Do Not Disturb
          );
    }

    if (Platform.isAndroid) {
      // Android permission check
      await plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      
      // Request exact alarms permission for Android 13+
      await plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestExactAlarmsPermission();
          
      // Also request general notification permission
      await requestNotificationPermission();
    }
  }

  Future<void> initNotification() async {
    if (_isInitialized) return;

    // Request permissions
    await requestPermissions();
    
    // Initialize timezone (for debugging)
    tz.initializeTimeZones();
    String timeZoneName;
    try {
      timeZoneName = await FlutterTimezone.getLocalTimezone();
    } catch (e) {
      timeZoneName = 'UTC';
      print('Error getting timezone: $e');
    }
    
    // Print debug information
    final now = DateTime.now();
    print("SYSTEM TIME: $now");
    print("TIMEZONE: $timeZoneName");
   
    // Initialize notifications
    const initSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: true, // For critical alerts
    );

    const initSettings = InitializationSettings(
      android: initSettingsAndroid,
      iOS: initSettingsIOS,
    );

    // Add callback to handle notification taps
    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('Notification tapped: ${response.payload}');
        // Handle notification tap here
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    _isInitialized = true;
    print("✅ Notification service initialized");
    
    // Check for any pending scheduled notifications
    checkPendingNotifications();
  }

  Future<void> showNotification({
    int id = 0,
    String? title,
    String? body,
    String? payload,
  }) async {
    try {
      await flutterLocalNotificationsPlugin.show(
        id,
        title,
        body,
        _notificationDetails,
        payload: payload,
      );
      print("✓ Notification shown successfully");
    } catch (e) {
      print("❌ Error showing notification: $e");
    }
  }
  
  // Schedule a notification that will work even when app is terminated
  Future<void> scheduleNotificationPersistent({
    int id = 2,
    required String title,
    required String body,
    required int hours,
    required int minutes,
    required int seconds,
    String? payload,
  }) async {
    try {
      // Cancel any existing notification with this ID
      await flutterLocalNotificationsPlugin.cancel(id);
      
      // Calculate scheduled time
      final scheduledTime = DateTime.now().add(
        Duration(
          hours: hours,
          minutes: minutes,
          seconds: seconds,
        ),
      );
      
      print("Scheduling persistent notification for: $scheduledTime (in $hours hours, $minutes minutes, $seconds seconds)");
      
      // Schedule using Timezone
      final scheduledDate = tz.TZDateTime.from(scheduledTime, tz.local);
      
      // For Android, set up enhanced notification details for better persistence
      final androidDetails = AndroidNotificationDetails(
        'persistent_channel_id',  // Use a distinct channel ID
        'Persistent Notifications',
        channelDescription: 'Notifications that work when app is terminated',
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.alarm,
        playSound: true,
        enableLights: true,
        enableVibration: true,
        autoCancel: false,  // Do not auto-cancel
      );
      
      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: _iOSNotificationDetails,
      );
      
      print("Scheduling persistent notification for: $scheduledDate");
      
      // Save notification details to shared preferences for recovery after termination
      await saveScheduledNotification(
        id: id,
        title: title,
        body: body, 
        scheduledTime: scheduledTime,
        payload: payload,
      );
      
      // Schedule with system alarm manager
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      
      print("✓ Persistent notification scheduled successfully for $scheduledTime");
      
    } catch (e) {
      print("❌ Error scheduling persistent notification: $e");
    }
  }
  


  
  // Save notification details to restore after app restart
  Future<void> saveScheduledNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save notification details as a simple JSON string
      await prefs.setString('notification_$id', 
        '{"id":$id,"title":"$title","body":"$body","time":"${scheduledTime.toIso8601String()}","payload":"$payload"}');
      
      // Save list of active notification IDs
      List<String> activeIds = prefs.getStringList('active_notifications') ?? [];
      if (!activeIds.contains('$id')) {
        activeIds.add('$id');
        await prefs.setStringList('active_notifications', activeIds);
      }
      
    } catch (e) {
      print('Error saving notification: $e');
    }
  }
  
  // Check for pending notifications when app starts
  Future<void> checkPendingNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeIds = prefs.getStringList('active_notifications') ?? [];
      
      if (activeIds.isEmpty) return;
      
      print('Found ${activeIds.length} pending notifications');
      
      // Create a list to track IDs that need to be removed
      final idsToRemove = <String>[];
      
      for (String idStr in activeIds) {
        final id = int.parse(idStr);
        final notificationJson = prefs.getString('notification_$id');
        
        if (notificationJson != null && notificationJson.isNotEmpty) {
          // Parse the notification details
          // This is a very simple implementation - in a real app you'd use proper JSON parsing
          
          // Extract time from the saved data
          final timeStr = notificationJson.split('"time":"')[1].split('","')[0];
          final scheduledTime = DateTime.parse(timeStr);
          
          // Only schedule if it's in the future
          if (scheduledTime.isAfter(DateTime.now())) {
            // Extract title and body
            final title = notificationJson.split('"title":"')[1].split('","')[0];
            final body = notificationJson.split('"body":"')[1].split('","')[0];
            final payload = notificationJson.split('"payload":"')[1].split('"}')[0];
            
            print('Rescheduling notification #$id for $scheduledTime');
            
            // Schedule it again
            final scheduledDate = tz.TZDateTime.from(scheduledTime, tz.local);
            
            await flutterLocalNotificationsPlugin.zonedSchedule(
              id,
              title,
              body,
              scheduledDate,
              _notificationDetails,
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
              payload: payload,
            );
          } else {
            // Mark for removal instead of removing during iteration
            idsToRemove.add(idStr);
            await prefs.remove('notification_$id');
          }
        }
      }
      
      // Now remove expired notifications from the list
      if (idsToRemove.isNotEmpty) {
        final updatedIds = activeIds.where((id) => !idsToRemove.contains(id)).toList();
        await prefs.setStringList('active_notifications', updatedIds);
      }
    } catch (e) {
      print('Error checking pending notifications: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    // Clear saved notifications
    final prefs = await SharedPreferences.getInstance();
    final activeIds = prefs.getStringList('active_notifications') ?? [];
    
    for (String idStr in activeIds) {
      await prefs.remove('notification_$idStr');
    }
    
    await prefs.remove('active_notifications');
    
    // Cancel all active notifications
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<void> scheduleBreakfastNotification() async {
    try {
      // Get current time
      final now = DateTime.now();
      print("Current time: $now");
      
      // Calculate target time for today
      final targetTime = DateTime(
        now.year,
        now.month,
        now.day,
        14,  // 13:00
        47,   // 09 minutes
        0,   // 0 seconds
      );
      
      // If time has passed, schedule for next day
      if (targetTime.isBefore(now)) {
        print("Breakfast time has passed for today, scheduling for tomorrow");
        final nextDay = targetTime.add(Duration(days: 1));
        print("Next breakfast notification will be at: $nextDay");
        
        // Calculate hours, minutes, seconds until next day
        final durationUntilNext = nextDay.difference(now);
        await scheduleNotificationPersistent(
          id: 4,
          title: "🍳 Time for Breakfast!",
          body: "Start your day right with a healthy breakfast. Don't skip the most important meal of the day!",
          hours: durationUntilNext.inHours,
          minutes: durationUntilNext.inMinutes.remainder(60),
          seconds: durationUntilNext.inSeconds.remainder(60),
        );
      } else {
        // Time hasn't passed yet, schedule for today
        print("Scheduling breakfast notification for today at: $targetTime");
        final durationUntilTarget = targetTime.difference(now);
        await scheduleNotificationPersistent(
          id: 4,
          title: "🍳 Time for Breakfast!",
          body: "Start your day right with a healthy breakfast. Don't skip the most important meal of the day!",
          hours: durationUntilTarget.inHours,
          minutes: durationUntilTarget.inMinutes.remainder(60),
          seconds: durationUntilTarget.inSeconds.remainder(60),
        );
      }
      
      print("✓ Breakfast notification scheduled");
    } catch (e) {
      print("❌ Error scheduling breakfast notification: $e");
    }
  }

  Future<void> scheduleDinnerNotification() async {
    try {
      // Calculate the next dinner time
      final now = DateTime.now();
      final dinnerTime = DateTime(
        now.year,
        now.month,
        now.day,
        now.hour + 12,  // Add 12 hours
        now.minute + 47,  // Add 47 minutes
        now.second + 15,  // Add 15 seconds
      );
      
      // If the time has passed, schedule for next day
      if (dinnerTime.isBefore(now)) {
        print("Dinner time has passed for today, scheduling for tomorrow");
      }
      
      print("Next dinner notification will be at: $dinnerTime");
      
      await scheduleNotificationPersistent(
        id: 5, // Unique ID for dinner notification
        title: "🍽️ Dinner Time!",
        body: "It's time to enjoy a delicious dinner. Remember to eat mindfully and savor your meal!",
        hours: 12,
        minutes: 47,
        seconds: 15,
      );
      print("✓ Dinner notification scheduled");
    } catch (e) {
      print("❌ Error scheduling dinner notification: $e");
    }
  }
}
