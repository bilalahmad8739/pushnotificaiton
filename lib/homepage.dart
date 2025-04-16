import 'package:flutter/material.dart';
import 'package:localnotificationandschudulenotficaton/services/notificationservices.dart';
import 'dart:async';

import 'package:localnotificationandschudulenotficaton/services/testnotification.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _notificationTimer;
  int _seconds = 17; // Default seconds
  
  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notification Demo'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              SizedBox(height: 20),
              
           const   Text(
                'Schedule a notification that works even when app is terminated',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              
              SizedBox(height: 20),
              
              // Controls for seconds
          
              
              ElevatedButton(
                  onPressed: () async {
                    print("Scheduling persistent notification (timer: $_seconds sec)");
                    
                    // Schedule notification using persistent method
                    // await NotificationService().scheduleNotificationPersistent(
                    //   title: "Persistent Notification",
                    //   body: "This notification works in foreground, background & when terminated",
                    //   seconds: 10,
                    //   //_seconds,
                    // );
                    
                    // Show user feedback
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Notification set for $_seconds seconds'))
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    textStyle: TextStyle(fontSize: 16),
                  ),
                  child: Text("Schedule Notification ($_seconds sec)")),
              
              SizedBox(height: 40),
               ElevatedButton(
                onPressed: () {
                  NotificationHelper.scheduleNotification(
                  "Scheduled Notification",
                  "Triggered after 10 seconds",
                  10,
                );
                },
                child: const Text("Set Notification")),
            ElevatedButton(
                onPressed: () {
               NotificationHelper.cancelAllNotifications();
                 // NotificationHelper().cancelAllNotifications();
                },
                child: const Text("Remove Notification")),
              
            
            
            ],
          ),
        ),
      ),
    );
  }
}
