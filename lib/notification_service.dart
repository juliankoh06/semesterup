import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'assignment_model.dart';

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

      // Create notification channel
      const androidChannel = AndroidNotificationChannel(
        'assignment_reminders',
        'Assignment Reminders',
        description: 'Notifications for assignment deadlines',
        importance: Importance.high,
      );

      await _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(
          androidChannel);
    } catch (e) {
      print('Failed to initialize notification service: $e');
      // Continue without notifications rather than crashing the app
    }
  }

  Future<void> scheduleAssignmentReminder(Assignment assignment) async {
    try {
      if (!assignment.reminderSettings.enabled) {
        return;
      }
      // Calculate scheduled time
      final scheduledTime = assignment.dueDate.subtract(
          assignment.reminderSettings.timeBefore);
      final now = DateTime.now();
      if (scheduledTime.isBefore(now)) {
        return;
      }
      await _notifications.zonedSchedule(
        assignment.id.hashCode,
        'Assignment Reminder',
        'Your assignment "${assignment.title}" is due in ${_formatDuration(
            assignment.reminderSettings.timeBefore.inMinutes)}',
        tz.TZDateTime.from(scheduledTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'assignment_reminders',
            'Assignment Reminders',
            channelDescription: 'Notifications for assignment deadlines',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation
            .absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dateAndTime,
      );
    } catch (e) {
      print('Failed to schedule assignment reminder: $e');
    }
  }

  Future<void> cancelAssignmentReminder(Assignment assignment) async {
    await _notifications.cancel(assignment.id.hashCode);
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
            'assignment_reminders',
            'Assignment Reminders',
            channelDescription: 'Notifications for assignment deadlines',
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

  Future<void> cancelAllReminders() async {
    await _notifications.cancelAll();
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes minutes';
    } else if (minutes < 1440) {
      final hours = minutes ~/ 60;
      return '$hours hour${hours > 1 ? 's' : ''}';
    } else if (minutes < 10080) {
      final days = minutes ~/ 1440;
      return '$days day${days > 1 ? 's' : ''}';
    } else {
      final weeks = minutes ~/ 10080;
      return '$weeks week${weeks > 1 ? 's' : ''}';
    }
  }
}