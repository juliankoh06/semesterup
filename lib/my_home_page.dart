import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'assignment_model.dart';

class AssignmentHomePage extends StatefulWidget {
  const AssignmentHomePage({Key? key}) : super(key: key);

  @override
  State<AssignmentHomePage> createState() => _AssignmentHomePageState();
}

class _AssignmentHomePageState extends State<AssignmentHomePage> {
  final CollectionReference assignmentsRef =
  FirebaseFirestore.instance.collection('assignments');

  List<Assignment> assignments = [];

  @override
  void initState() {
    super.initState();
    fetchAssignments();
  }

  Future<void> fetchAssignments() async {
    final snapshot = await assignmentsRef.get();
    if (mounted) {
      assignments = snapshot.docs.map((doc) {
        var map = doc.data() as Map<String, dynamic>;
        map['id'] = doc.id;
        return Assignment.fromMap(map);
      }).toList();
      setState(() {});
    }
  }

  Future<void> deleteAssignment(String id) async {
    await assignmentsRef.doc(id).delete();
    fetchAssignments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assignments'),
        backgroundColor: Colors.deepPurple,
      ),
      body: ListView.builder(
        itemCount: assignments.length,
        itemBuilder: (context, index) {
          final assignment = assignments[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              title: Text(assignment.title),
              subtitle: Text(
                'Due: ${assignment.dueDate.toLocal()}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => deleteAssignment(assignment.id),
              ),
              onTap: () {
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          // add new assignment
        },
      ),
    );
  }
}
