import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    try {
      const androidSettings = AndroidInitializationSettings(
          '@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(initSettings);

      // Create notification channel for study session endings
      const studySessionChannel = AndroidNotificationChannel(
        'study_session_endings',
        'Study Session Endings',
        description: 'Notifications for when a study session ends',
        importance: Importance.high,
      );
      await _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(
          studySessionChannel);
    } catch (e) {
      print('Failed to initialize notification service: $e');
      // Continue without notifications rather than crashing the app
    }
  }

  Future<void> showStudyTimerNotification(
      {required String title, required String body}) async {
    try {
      await _notifications.show(
        DateTime
            .now()
            .millisecondsSinceEpoch
            .remainder(100000), // Unique ID
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'study_session_endings',
            'Study Session Endings',
            channelDescription: 'Notifications for when a study session ends',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      print('Failed to show study timer notification: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
} 