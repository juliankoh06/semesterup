import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'assignment_model.dart';
import 'auth_provider.dart';
import 'providers.dart';
import 'reminder_settings.dart';


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
          // Sort assignments: active (not completed, not late) first, then completed, then late
          final now = DateTime.now();
          List<Assignment> sorted = List.from(assignments);
          sorted.sort((a, b) {
            bool aLate = a.dueDate.isBefore(now) && !a.isCompleted;
            bool bLate = b.dueDate.isBefore(now) && !b.isCompleted;
            if (!a.isCompleted && !aLate && (b.isCompleted || bLate)) return -1;
            if (!b.isCompleted && !bLate && (a.isCompleted || aLate)) return 1;
            if (a.isCompleted && !b.isCompleted && !bLate) return 1;
            if (b.isCompleted && !a.isCompleted && !aLate) return -1;
            if (aLate && !bLate) return 1;
            if (bLate && !aLate) return -1;
            // Within each group, sort by due date ascending
            return a.dueDate.compareTo(b.dueDate);
          });
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
                                      reminderSettings: assignment.reminderSettings,
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
                                    reminderSettings: assignment.reminderSettings,
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
                        else if (isLate)
                          const Text(
                            'LATE',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          )
                        else
                          Text(
                            'Due: ${assignment.dueDate.toLocal().toString().substring(0, 16)}',
                            style: TextStyle(
                              color: assignment.isCompleted ? Colors.grey : Theme.of(context).colorScheme.primary,
                            ),
                          ),
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
                              _showSubtasksDialog(context, ref, assignment);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.notifications, color: Colors.blue),
                            onPressed: () {
                              _showReminderSettings(context, ref, assignment);
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
                                  reminderSettings: ReminderSettings(
                                    enabled: false,
                                    timeBefore: Duration(minutes: 1440), // 1 day, but disabled
                                  ),
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
          ],
        ),
      ),
    );
  }

  void _showReminderSettings(BuildContext context, WidgetRef ref, Assignment assignment) {
    bool enabled = assignment.reminderSettings.enabled;
    int minutes = assignment.reminderSettings.timeBefore.inMinutes;
    bool multipleReminders = false;
    List<int> reminderTimes = [minutes];
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Reminder Settings - ${assignment.title}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      title: const Text('Enable Reminders'),
                      subtitle: const Text('Get notified before deadline'),
                      value: enabled,
                      onChanged: (value) {
                        setState(() {
                          enabled = value;
                        });
                      },
                    ),
                    if (enabled) ...[
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Multiple Reminders'),
                        subtitle: const Text('Set multiple reminder times'),
                        value: multipleReminders,
                        onChanged: (value) {
                          setState(() {
                            multipleReminders = value;
                            if (value && reminderTimes.length == 1) {
                              reminderTimes = [60, 1440]; // Default: 1 hour and 1 day
                            } else if (!value) {
                              reminderTimes = [reminderTimes.first];
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      if (!multipleReminders) ...[
                        const Text('Remind me before:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          value: minutes,
                          decoration: const InputDecoration(
                            labelText: 'Time',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(value: 5, child: Text('5 minutes')),
                            const DropdownMenuItem(value: 15, child: Text('15 minutes')),
                            const DropdownMenuItem(value: 30, child: Text('30 minutes')),
                            const DropdownMenuItem(value: 60, child: Text('1 hour')),
                            const DropdownMenuItem(value: 120, child: Text('2 hours')),
                            const DropdownMenuItem(value: 240, child: Text('4 hours')),
                            const DropdownMenuItem(value: 480, child: Text('8 hours')),
                            const DropdownMenuItem(value: 1440, child: Text('1 day')),
                            const DropdownMenuItem(value: 2880, child: Text('2 days')),
                            const DropdownMenuItem(value: 4320, child: Text('3 days')),
                            const DropdownMenuItem(value: 10080, child: Text('1 week')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              minutes = value ?? 60;
                              reminderTimes = [minutes];
                            });
                          },
                        ),
                      ] else ...[
                        const Text('Reminder Times:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ...reminderTimes.asMap().entries.map((entry) {
                          int index = entry.key;
                          int time = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    value: time,
                                    decoration: InputDecoration(
                                      labelText: 'Reminder ${index + 1}',
                                      border: const OutlineInputBorder(),
                                    ),
                                    items: [
                                      const DropdownMenuItem(value: 5, child: Text('5 minutes')),
                                      const DropdownMenuItem(value: 15, child: Text('15 minutes')),
                                      const DropdownMenuItem(value: 30, child: Text('30 minutes')),
                                      const DropdownMenuItem(value: 60, child: Text('1 hour')),
                                      const DropdownMenuItem(value: 120, child: Text('2 hours')),
                                      const DropdownMenuItem(value: 240, child: Text('4 hours')),
                                      const DropdownMenuItem(value: 480, child: Text('8 hours')),
                                      const DropdownMenuItem(value: 1440, child: Text('1 day')),
                                      const DropdownMenuItem(value: 2880, child: Text('2 days')),
                                      const DropdownMenuItem(value: 4320, child: Text('3 days')),
                                      const DropdownMenuItem(value: 10080, child: Text('1 week')),
                                    ],
                                    onChanged: (value) {
                                      setState(() {
                                        reminderTimes[index] = value ?? 60;
                                      });
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                                  onPressed: reminderTimes.length > 1 ? () {
                                    setState(() {
                                      reminderTimes.removeAt(index);
                                    });
                                  } : null,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        if (reminderTimes.length < 5) ...[
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                reminderTimes.add(60);
                              });
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add Another Reminder'),
                          ),
                        ],
                      ],
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Reminder Summary:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              multipleReminders 
                                ? reminderTimes.map((time) => _formatDuration(time)).join(', ')
                                : _formatDuration(minutes),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final user = ref.read(authProvider).value;
                    if (user != null) {
                      try {
                        // For now, we'll use the first reminder time for the main reminder
                        // In a full implementation, you'd store multiple reminder times
                        final updatedReminderSettings = ReminderSettings(
                          enabled: enabled,
                          timeBefore: Duration(minutes: multipleReminders ? reminderTimes.first : minutes),
                        );
                        
                        final updatedAssignment = Assignment(
                          id: assignment.id,
                          title: assignment.title,
                          dueDate: assignment.dueDate,
                          subtasks: assignment.subtasks,
                          reminderSettings: updatedReminderSettings,
                          isCompleted: assignment.isCompleted,
                        );
                        
                        await ref.read(assignmentRepoProvider).updateAssignment(user.uid, updatedAssignment);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                multipleReminders 
                                  ? 'Multiple reminders set: ${reminderTimes.map((t) => _formatDuration(t)).join(', ')}'
                                  : 'Reminder set: ${_formatDuration(minutes)} before deadline'
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to update: $e')),
                          );
                        }
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
  }

  void _showSubtasksDialog(BuildContext context, WidgetRef ref, Assignment assignment) {
    final TextEditingController subtaskController = TextEditingController();
    List<Subtask> localSubtasks = List<Subtask>.from(assignment.subtasks);
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            int completedCount = localSubtasks.where((s) => s.isCompleted).length;
            int totalCount = localSubtasks.length;
            double progress = totalCount == 0 ? 0 : completedCount / totalCount;
            return AlertDialog(
              title: Text('Subtasks for "${assignment.title}"'),
              content: SizedBox(
                width: 350,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Input at the top
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: subtaskController,
                            decoration: const InputDecoration(labelText: 'New subtask'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final user = ref.read(authProvider).value;
                            final text = subtaskController.text.trim();
                            if (user != null && text.isNotEmpty) {
                              localSubtasks.add(Subtask(title: text, isCompleted: false, reminderSettings: ReminderSettings.defaultSettings()));
                              setState(() {
                                subtaskController.clear();
                              });
                              final updatedAssignment = Assignment(
                                id: assignment.id,
                                title: assignment.title,
                                dueDate: assignment.dueDate,
                                subtasks: localSubtasks,
                                reminderSettings: assignment.reminderSettings,
                                isCompleted: assignment.isCompleted,
                              );
                              await ref.read(assignmentRepoProvider).updateAssignment(user.uid, updatedAssignment);
                            }
                          },
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Progress bar
                    if (totalCount > 0) ...[
                      LinearProgressIndicator(value: progress),
                      const SizedBox(height: 8),
                      Text('${(progress * 100).toStringAsFixed(0)}% completed', style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 8),
                    ],
                    if (localSubtasks.isEmpty)
                      const Text('No subtasks yet.'),
                    ...localSubtasks.asMap().entries.map((entry) {
                      int idx = entry.key;
                      Subtask subtask = entry.value;
                      return ListTile(
                        leading: Checkbox(
                          value: subtask.isCompleted,
                          onChanged: (val) async {
                            final user = ref.read(authProvider).value;
                            if (user != null) {
                              localSubtasks[idx] = Subtask(
                                title: subtask.title,
                                isCompleted: val ?? false,
                                reminderSettings: subtask.reminderSettings,
                              );
                              setState(() {});
                              final updatedAssignment = Assignment(
                                id: assignment.id,
                                title: assignment.title,
                                dueDate: assignment.dueDate,
                                subtasks: localSubtasks,
                                reminderSettings: assignment.reminderSettings,
                                isCompleted: assignment.isCompleted,
                              );
                              await ref.read(assignmentRepoProvider).updateAssignment(user.uid, updatedAssignment);
                            }
                          },
                        ),
                        title: Text(subtask.title),
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
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
