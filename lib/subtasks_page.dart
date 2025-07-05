import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'assignment_model.dart';
import 'auth_provider.dart';
import 'providers.dart';

class SubtasksPage extends ConsumerStatefulWidget {
  final Assignment assignment;

  const SubtasksPage({super.key, required this.assignment});

  @override
  ConsumerState<SubtasksPage> createState() => _SubtasksPageState();
}

class _SubtasksPageState extends ConsumerState<SubtasksPage> {
  final TextEditingController _subtaskController = TextEditingController();
  List<Subtask> _localSubtasks = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _localSubtasks = List<Subtask>.from(widget.assignment.subtasks);
  }

  @override
  void dispose() {
    _subtaskController.dispose();
    super.dispose();
  }

  Future<void> _addSubtask() async {
    final text = _subtaskController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = ref.read(authProvider).value;
      if (user != null) {
        _localSubtasks.add(Subtask(title: text, isCompleted: false));
        _subtaskController.clear();
        
        final updatedAssignment = Assignment(
          id: widget.assignment.id,
          title: widget.assignment.title,
          dueDate: widget.assignment.dueDate,
          subtasks: _localSubtasks,
          isCompleted: widget.assignment.isCompleted,
        );
        
        await ref.read(assignmentRepoProvider).updateAssignment(user.uid, updatedAssignment);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Subtask added successfully!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add subtask: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleSubtask(int index) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = ref.read(authProvider).value;
      if (user != null) {
        final subtask = _localSubtasks[index];
        _localSubtasks[index] = Subtask(
          title: subtask.title,
          isCompleted: !subtask.isCompleted,
        );
        
        final updatedAssignment = Assignment(
          id: widget.assignment.id,
          title: widget.assignment.title,
          dueDate: widget.assignment.dueDate,
          subtasks: _localSubtasks,
          isCompleted: widget.assignment.isCompleted,
        );
        
        await ref.read(assignmentRepoProvider).updateAssignment(user.uid, updatedAssignment);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update subtask: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteSubtask(int index) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = ref.read(authProvider).value;
      if (user != null) {
        _localSubtasks.removeAt(index);
        
        final updatedAssignment = Assignment(
          id: widget.assignment.id,
          title: widget.assignment.title,
          dueDate: widget.assignment.dueDate,
          subtasks: _localSubtasks,
          isCompleted: widget.assignment.isCompleted,
        );
        
        await ref.read(assignmentRepoProvider).updateAssignment(user.uid, updatedAssignment);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Subtask deleted successfully!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete subtask: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _localSubtasks.where((s) => s.isCompleted).length;
    final totalCount = _localSubtasks.length;
    final progress = totalCount == 0 ? 0.0 : completedCount / totalCount;

    return Scaffold(
      appBar: AppBar(
        title: Text('Subtasks - ${widget.assignment.title}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment),
            tooltip: 'Back to Assignments',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: _localSubtasks.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.checklist_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No subtasks yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Add subtasks to break down your assignment',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _localSubtasks.length,
              itemBuilder: (context, index) {
                final subtask = _localSubtasks[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                    child: ListTile(
                      leading: Checkbox(
                        value: subtask.isCompleted,
                        onChanged: _isLoading ? null : (_) => _toggleSubtask(index),
                      ),
                      title: Text(
                        subtask.title,
                        style: TextStyle(
                          color: subtask.isCompleted ? Colors.green : null,
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                        ),
                      ),
                      subtitle: subtask.isCompleted
                          ? const Text(
                              'COMPLETED',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            )
                          : null,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: _isLoading 
                          ? null 
                          : () => _deleteSubtask(index),
                        tooltip: 'Delete subtask',
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(right: 16, bottom: 16),
        child: FloatingActionButton(
          heroTag: 'addSubtaskBtn',
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: const Text('New Subtask'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _subtaskController,
                        decoration: const InputDecoration(labelText: 'Subtask Title'),
                        autofocus: true,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final text = _subtaskController.text.trim();
                        if (text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a subtask title')),
                          );
                          return;
                        }
                        if (text.length > 50) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Title is too long (max 50 characters)')),
                          );
                          return;
                        }
                        
                        Navigator.of(context).pop();
                        await _addSubtask();
                      },
                      child: const Text('Add'),
                    ),
                  ],
                );
              },
            );
          },
          child: const Icon(Icons.add),
          tooltip: 'Add Subtask',
        ),
      ),
    );
  }
} 