import 'package:cloud_firestore/cloud_firestore.dart';
import 'assignment_model.dart';

class AssignmentRepository {
  final _firestore = FirebaseFirestore.instance;

  Stream<List<Assignment>> getAssignments(String uid) {
    return _firestore
        .collection('users/$uid/assignments')
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) {
          var map = doc.data();
          map['id'] = doc.id;
          return Assignment.fromMap(map);
        })
        .toList());
  }

  Future<void> addAssignment(String uid, Assignment assignment) async {
    await _firestore.collection('users/$uid/assignments').doc(assignment.id).set(assignment.toMap());
  }

  Future<void> updateAssignment(String uid, Assignment assignment) async {
    await _firestore
        .collection('users/$uid/assignments')
        .doc(assignment.id)
        .set(assignment.toMap());
  }

  Future<void> deleteAssignment(String uid, String id) async {
    try {
      await _firestore.collection('users/$uid/assignments').doc(id).delete();
    } catch (e) {
      print('Failed to delete assignment: $e');
      rethrow;
    }
  }
}
