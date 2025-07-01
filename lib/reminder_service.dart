import 'package:cloud_firestore/cloud_firestore.dart';

class ReminderService {
  final _firestore = FirebaseFirestore.instance;

  Future<void> scheduleReminder(String uid, String assignmentId, Map<String, dynamic> reminderSettings) async {
    await _firestore
        .collection('users/$uid/assignments')
        .doc(assignmentId)
        .update({'reminderSettings': reminderSettings});

  }
}