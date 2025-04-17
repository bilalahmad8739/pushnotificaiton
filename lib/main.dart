import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:localnotificationandschudulenotficaton/homepage.dart';
import 'package:localnotificationandschudulenotficaton/services/notificationservices.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:localnotificationandschudulenotficaton/services/testnotification.dart';

void notificationCallback() {
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  const androidDetails = AndroidNotificationDetails(
    'channel_id', 'channel_name',
    importance: Importance.max,
    priority: Priority.high,
  );

  flutterLocalNotificationsPlugin.show(
    0,
    'Notification from AlarmManager',
    'This fired even after terminated!',
    const NotificationDetails(android: androidDetails),
  );
}

Future<void> main() async {

  print('idress branch');

  

  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize notification helper
  await NotificationHelper.init();
  
  // Initialize notification service
  final notificationService = NotificationService();
  await notificationService.initNotification();
  
  // Schedule breakfast notification
  await notificationService.scheduleBreakfastNotification();
  
  // Schedule dinner notification
  await notificationService.scheduleDinnerNotification();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: HomeScreen(),
    );
  }
}
