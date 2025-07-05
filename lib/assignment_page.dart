import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'assignment_model.dart';
import 'auth_provider.dart';
import 'providers.dart';
import 'subtasks_page.dart';



class AssignmentPage extends ConsumerWidget {
  const AssignmentPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync = ref.watch(assignmentsProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Assignments Due'),
        actions: [
          IconButton(
            icon: const Icon(Icons.timer),
            tooltip: 'Study Timer',
            onPressed: () => Navigator.pushNamed(context, '/study-timer'),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Timetable',
            onPressed: () => Navigator.pushNamed(context, '/timetable'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Show confirmation dialog
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
              
              if (confirmed == true) {
                try {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Logged out successfully')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to logout: $e')),
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
      body: assignmentsAsync.when(
        data: (assignments) {
          final now = DateTime.now();
          List<Assignment> active = [];
          List<Assignment> completed = [];
          List<Assignment> late = [];

          // Categorize assignments
          for (var assignment in assignments) {
            if (assignment.isCompleted) {
              completed.add(assignment);
            } else if (assignment.dueDate.isBefore(now)) {
              late.add(assignment);
            } else {
              active.add(assignment);
            }
          }

          // Sort each group by due date
          active.sort((a, b) => a.dueDate.compareTo(b.dueDate));
          completed.sort((a, b) => a.dueDate.compareTo(b.dueDate));
          late.sort((a, b) => a.dueDate.compareTo(b.dueDate));

          // Combine the lists: active first, then completed, then late
          List<Assignment> sorted = [...active, ...completed, ...late];
          return ListView.builder(
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              final assignment = sorted[index];
              final now = DateTime.now();
              final isLate = assignment.dueDate.isBefore(now) && !assignment.isCompleted;
              
              return Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                  child: ListTile(
                    leading: (!isLate && !assignment.isCompleted)
                        ? Checkbox(
                            value: assignment.isCompleted,
                            onChanged: (bool? value) async {
                              final user = ref.read(authProvider).value;
                              if (user != null) {
                                if (value == true && !assignment.isCompleted) {
                                  // Show confirmation dialog
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Mark as Completed'),
                                      content: const Text('Are you sure you want to mark this assignment as completed?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => Navigator.of(context).pop(true),
                                          child: const Text('Yes'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) {
                                    final updatedAssignment = Assignment(
                                      id: assignment.id,
                                      title: assignment.title,
                                      dueDate: assignment.dueDate,
                                      subtasks: assignment.subtasks,
                                      isCompleted: true,
                                    );
                                    await ref.read(assignmentRepoProvider).updateAssignment(user.uid, updatedAssignment);
                                  }
                                } else if (value == false && assignment.isCompleted) {
                                  // Uncheck: mark as not completed
                                  final updatedAssignment = Assignment(
                                    id: assignment.id,
                                    title: assignment.title,
                                    dueDate: assignment.dueDate,
                                    subtasks: assignment.subtasks,
                                    isCompleted: false,
                                  );
                                  await ref.read(assignmentRepoProvider).updateAssignment(user.uid, updatedAssignment);
                                }
                              }
                            },
                          )
                        : null,
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            assignment.title,
                            style: TextStyle(
                              color: assignment.isCompleted ? Colors.green : null,
                              fontWeight: FontWeight.w600,
                              fontSize: 17,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (assignment.isCompleted)
                          const Text(
                            'COMPLETED',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          )
                        else if (isLate) ...[
                          const Text(
                            'LATE',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Due: ${assignment.dueDate.toLocal().toString().substring(0, 16)}',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ]
                        else
                          Text(
                            'Due: ${assignment.dueDate.toLocal().toString().substring(0, 16)}',
                            style: TextStyle(
                              color: assignment.isCompleted ? Colors.grey : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        if (assignment.subtasks.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Subtasks: ${(assignment.subtasks.where((s) => s.isCompleted).length / assignment.subtasks.length * 100).toStringAsFixed(0)}% complete',
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!assignment.isCompleted && !isLate) ...[
                          IconButton(
                            icon: const Icon(Icons.checklist),
                            tooltip: 'Manage Subtasks',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SubtasksPage(assignment: assignment),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.orange),
                            tooltip: 'Edit Assignment',
                            onPressed: () {
                              final titleController = TextEditingController(text: assignment.title);
                              DateTime? selectedDate = assignment.dueDate;
                              TimeOfDay? selectedTime = TimeOfDay(hour: assignment.dueDate.hour, minute: assignment.dueDate.minute);
                              String? errorMessage;
                              showDialog(
                                context: context,
                                builder: (context) {
                                  return StatefulBuilder(
                                    builder: (context, setState) {
                                      return AlertDialog(
                                        title: const Text('Edit Assignment'),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TextField(
                                              controller: titleController,
                                              decoration: const InputDecoration(labelText: 'Title'),
                                            ),
                                            const SizedBox(height: 16),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: ElevatedButton.icon(
                                                    onPressed: () async {
                                                      final date = await showDatePicker(
                                                        context: context,
                                                        initialDate: selectedDate ?? DateTime.now(),
                                                        firstDate: DateTime.now(),
                                                        lastDate: DateTime.now().add(const Duration(days: 365)),
                                                      );
                                                      if (date != null) {
                                                        setState(() {
                                                          selectedDate = date;
                                                        });
                                                      }
                                                    },
                                                    icon: const Icon(Icons.calendar_today),
                                                    label: Text(selectedDate == null 
                                                      ? 'Select Date' 
                                                      : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: ElevatedButton.icon(
                                                    onPressed: () async {
                                                      final time = await showTimePicker(
                                                        context: context,
                                                        initialTime: selectedTime ?? TimeOfDay.now(),
                                                      );
                                                      if (time != null) {
                                                        setState(() {
                                                          selectedTime = time;
                                                        });
                                                      }
                                                    },
                                                    icon: const Icon(Icons.access_time),
                                                    label: Text(selectedTime == null 
                                                      ? 'Select Time' 
                                                      : selectedTime!.format(context)),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (errorMessage != null) ...[
                                              const SizedBox(height: 12),
                                              Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                                            ],
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () async {
                                              final user = ref.read(authProvider).value;
                                              if (user == null) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Please sign in first')),
                                                );
                                                return;
                                              }
                                              final title = titleController.text.trim();
                                              if (title.isEmpty) {
                                                setState(() {
                                                  errorMessage = 'Please enter a title';
                                                });
                                                return;
                                              }
                                              if (title.length > 50) {
                                                setState(() {
                                                  errorMessage = 'Title is too long (max 50 characters)';
                                                });
                                                return;
                                              }
                                              if (selectedDate == null || selectedTime == null) {
                                                setState(() {
                                                  errorMessage = 'Please select both a date and time';
                                                });
                                                return;
                                              }
                                              DateTime dueDateTime = DateTime(
                                                selectedDate!.year,
                                                selectedDate!.month,
                                                selectedDate!.day,
                                                selectedTime!.hour,
                                                selectedTime!.minute,
                                              );
                                              final updatedAssignment = Assignment(
                                                id: assignment.id,
                                                title: title,
                                                dueDate: dueDateTime,
                                                subtasks: assignment.subtasks,
                                                isCompleted: assignment.isCompleted,
                                              );
                                              try {
                                                await ref.read(assignmentRepoProvider).updateAssignment(user.uid, updatedAssignment);
                                                if (context.mounted) {
                                                  Navigator.of(context).pop();
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Assignment updated successfully!')),
                                                  );
                                                }
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('Failed to update: $e')),
                                                  );
                                                }
                                              }
                                            },
                                            child: const Text('Save'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ] else ...[
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Delete Assignment',
                            onPressed: () async {
                              final user = ref.read(authProvider).value;
                              if (user != null) {
                                try {
                                  await ref.read(assignmentRepoProvider).deleteAssignment(user.uid, assignment.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Assignment deleted successfully')),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed to delete assignment: $e')),
                                    );
                                  }
                                }
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(right: 16, bottom: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              heroTag: 'deleteBtn',
              backgroundColor: Colors.red,
              onPressed: () async {
                final assignments = ref.read(assignmentsProvider).value ?? [];
                if (assignments.isEmpty) return;
                List<String> selectedIds = [];
                await showDialog(
                  context: context,
                  builder: (context) {
                    return StatefulBuilder(
                      builder: (context, setState) {
                        return AlertDialog(
                          title: const Text('Delete Assignment'),
                          content: SizedBox(
                            width: 350,
                            child: ListView(
                              shrinkWrap: true,
                              children: List<Widget>.from(assignments.map((a) => CheckboxListTile(
                                    value: selectedIds.contains(a.id),
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          selectedIds.add(a.id);
                                        } else {
                                          selectedIds.remove(a.id);
                                        }
                                      });
                                    },
                                    title: Text(a.title),
                                  ))),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: () async {
                                final user = ref.read(authProvider).value;
                                if (user != null) {
                                  try {
                                    for (final id in selectedIds) {
                                      await ref.read(assignmentRepoProvider).deleteAssignment(user.uid, id);
                                    }
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Assignments deleted successfully')),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Failed to delete assignments: $e')),
                                      );
                                    }
                                  }
                                }
                                Navigator.of(context).pop();
                              },
                              child: const Text('Delete'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
              child: const Icon(Icons.delete),
              tooltip: 'Delete Assignment',
            ),
            const SizedBox(width: 16),
            FloatingActionButton(
              heroTag: 'addBtn',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    final titleController = TextEditingController();
                    DateTime? selectedDate;
                    TimeOfDay? selectedTime;
                    String? errorMessage;
                    
                    return StatefulBuilder(
                      builder: (context, setState) {
                        return AlertDialog(
                          title: const Text('New Assignment'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(
                                controller: titleController,
                                decoration: const InputDecoration(labelText: 'Title'),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        final date = await showDatePicker(
                                          context: context,
                                          initialDate: DateTime.now(),
                                          firstDate: DateTime.now(),
                                          lastDate: DateTime.now().add(const Duration(days: 365)),
                                        );
                                        if (date != null) {
                                          setState(() {
                                            selectedDate = date;
                                          });
                                        }
                                      },
                                      icon: const Icon(Icons.calendar_today),
                                      label: Text(selectedDate == null 
                                        ? 'Select Date' 
                                        : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        final time = await showTimePicker(
                                          context: context,
                                          initialTime: TimeOfDay.now(),
                                        );
                                        if (time != null) {
                                          setState(() {
                                            selectedTime = time;
                                          });
                                        }
                                      },
                                      icon: const Icon(Icons.access_time),
                                      label: Text(selectedTime == null 
                                        ? 'Select Time' 
                                        : selectedTime!.format(context)),
                                    ),
                                  ),
                                ],
                              ),
                              if (errorMessage != null) ...[
                                const SizedBox(height: 12),
                                Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                              ],
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                final user = ref.read(authProvider).value;
                                if (user == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please sign in first')),
                                  );
                                  return;
                                }

                                final title = titleController.text.trim();
                                
                                if (title.isEmpty) {
                                  setState(() {
                                    errorMessage = 'Please enter a title';
                                  });
                                  return;
                                }
                                if (title.length > 50) {
                                  setState(() {
                                    errorMessage = 'Title is too long (max 50 characters)';
                                  });
                                  return;
                                }
                                if (selectedDate == null || selectedTime == null) {
                                  setState(() {
                                    errorMessage = 'Please select both a date and time';
                                  });
                                  return;
                                }

                                // Combine date and time
                                DateTime dueDateTime = DateTime(
                                  selectedDate!.year,
                                  selectedDate!.month,
                                  selectedDate!.day,
                                  selectedTime!.hour,
                                  selectedTime!.minute,
                                );

                                final newAssignment = Assignment(
                                  id: FirebaseFirestore.instance.collection('assignments').doc().id,
                                  title: title,
                                  dueDate: dueDateTime,
                                  subtasks: [],
                                );

                                try {
                                  await ref.read(assignmentRepoProvider).addAssignment(user.uid, newAssignment);
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Assignment added successfully!')),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed to add: $e')),
                                    );
                                  }
                                }
                              },
                              child: const Text('Add'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
              child: const Icon(Icons.add),
              tooltip: 'Add Assignment',
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }


}
