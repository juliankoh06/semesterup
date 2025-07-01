import 'package:cloud_firestore/cloud_firestore.dart';
import 'reminder_settings.dart';

class Subtask {
  final String title;
  final bool isCompleted;
  final ReminderSettings reminderSettings;

  Subtask({
    required this.title,
    this.isCompleted = false,
    required this.reminderSettings,
  });

  Map<String, dynamic> toMap() => {
    'title': title,
    'isCompleted': isCompleted,
    'reminderSettings': reminderSettings.toMap(),
  };

  factory Subtask.fromMap(Map<String, dynamic> map) => Subtask(
    title: map['title'] ?? '',
    isCompleted: map['isCompleted'] ?? false,
    reminderSettings: ReminderSettings.fromMap(map['reminderSettings'] ?? {}),
  );
}

class Assignment {
  final String id;
  final String title;
  final DateTime dueDate;
  final List<Subtask> subtasks;
  final ReminderSettings reminderSettings;
  final bool isCompleted;

  Assignment({
    required this.id,
    required this.title,
    required this.dueDate,
    required this.subtasks,
    required this.reminderSettings,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'dueDate': dueDate,
      'subtasks': subtasks.map((s) => s.toMap()).toList(),
      'reminderSettings': reminderSettings.toMap(),
      'isCompleted': isCompleted,
    };
  }

  factory Assignment.fromMap(Map<String, dynamic> map) {
    return Assignment(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      dueDate: (map['dueDate'] as Timestamp).toDate(),
      subtasks: (map['subtasks'] as List<dynamic>? ?? []).map((s) => Subtask.fromMap(s as Map<String, dynamic>)).toList(),
      reminderSettings: ReminderSettings.fromMap(map['reminderSettings'] ?? {}),
      isCompleted: map['isCompleted'] ?? false,
    );
  }
}
