import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ClassSchedule {
  final String id;
  final String className;
  final int dayOfWeek;   //1 = Monday   7 = Sunday
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String? location;

  ClassSchedule({
    required this.id,
    required this.className,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.location,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'className': className,
        'dayOfWeek': dayOfWeek,
        'startHour': startTime.hour,
        'startMinute': startTime.minute,
        'endHour': endTime.hour,
        'endMinute': endTime.minute,
        'location': location,
      };

  factory ClassSchedule.fromMap(Map<String, dynamic> map) => ClassSchedule(
        id: map['id'] ?? '',
        className: map['className'] ?? '',
        dayOfWeek: map['dayOfWeek'] ?? 1,
        startTime: TimeOfDay(hour: map['startHour'] ?? 8, minute: map['startMinute'] ?? 0),
        endTime: TimeOfDay(hour: map['endHour'] ?? 9, minute: map['endMinute'] ?? 0),
        location: map['location'],
      );
}

class TimetablePage extends StatefulWidget {
  const TimetablePage({Key? key}) : super(key: key);

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  List<ClassSchedule> _classes = [];
  late final String? _uid;
  late final CollectionReference _timetableRef;
  late final DocumentReference? _colorSettingsRef;
  bool _loading = true;

  // Customize color for each day
  List<Color> _dayColors = [
    Colors.blue, Colors.blue, Colors.blue, Colors.blue, Colors.blue, Colors.blue, Colors.blue
  ];

  static const List<String> _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];
  // Color options
  static const List<Color> _colorOptions = [
    Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.brown, Colors.pink, Colors.indigo, Colors.amber
  ];

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    if (_uid != null) {
      _timetableRef = FirebaseFirestore.instance.collection('users/$_uid/timetable');
      _colorSettingsRef = FirebaseFirestore.instance.collection('users').doc(_uid).collection('settings').doc('timetable_colors');
      _listenToTimetable();
      _loadDayColors();
    } else {
      _colorSettingsRef = null;
    }
  }

  void _listenToTimetable() {
    _timetableRef.snapshots().listen((snapshot) {
      setState(() {
        _classes = snapshot.docs.map((doc) => ClassSchedule.fromMap(doc.data() as Map<String, dynamic>)).toList();
        _loading = false;
      });
    });
  }

  Future<void> _loadDayColors() async {
    if (_colorSettingsRef == null) return;
    final doc = await _colorSettingsRef!.get();
    if (doc.exists && doc['colors'] is List) {
      final List colors = doc['colors'];
      setState(() {
        _dayColors = List<Color>.generate(7, (i) => i < colors.length ? Color(colors[i]) : Colors.blue);
      });
    }
  }

  Future<void> _saveDayColors() async {
    if (_colorSettingsRef == null) return;
    await _colorSettingsRef!.set({
      'colors': _dayColors.map((c) => c.value).toList(),
    });
  }

  void _pickDayColor(int dayIndex) async {
    Color selected = _dayColors[dayIndex];
    final result = await showDialog<Color>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Pick a color for ${_days[dayIndex]}'),
          content: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _colorOptions.map((color) => GestureDetector(
              onTap: () => Navigator.of(context).pop(color),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected == color ? Colors.black : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
            )).toList(),
          ),
        );
      },
    );
    if (result != null) {
      setState(() {
        _dayColors[dayIndex] = result;
      });
      await _saveDayColors();
    }
  }

  Future<void> _addClass() async {
    String? className;
    int dayOfWeek = 1;
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    String? location;

    final result = await showDialog<ClassSchedule>(
      context: context,
      builder: (context) {
        String? errorMessage;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Class'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(labelText: 'Class Name'),
                      onChanged: (val) => className = val,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: dayOfWeek,
                      items: List.generate(7, (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text(_days[i]),
                      )),
                      onChanged: (val) => setState(() => dayOfWeek = val ?? 1),
                      decoration: const InputDecoration(labelText: 'Day'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.access_time),
                            label: Text(startTime == null ? 'Start Time' : startTime!.format(context)),
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay(hour: 8, minute: 0),
                              );
                              if (picked != null) setState(() => startTime = picked);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.access_time),
                            label: Text(endTime == null ? 'End Time' : endTime!.format(context)),
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay(hour: 9, minute: 0),
                              );
                              if (picked != null) setState(() => endTime = picked);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(labelText: 'Location (optional)'),
                      onChanged: (val) => location = val,
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(errorMessage!, style: const TextStyle(color: Colors.red)),
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
                  onPressed: () {
                    if (className == null || className!.trim().isEmpty) {
                      setState(() => errorMessage = 'Class name is required');
                      return;
                    }
                    if (startTime == null || endTime == null) {
                      setState(() => errorMessage = 'Start and end time are required');
                      return;
                    }
                    final newClass = ClassSchedule(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      className: className!,
                      dayOfWeek: dayOfWeek,
                      startTime: startTime!,
                      endTime: endTime!,
                      location: location,
                    );
                    Navigator.of(context).pop(newClass);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && _uid != null) {
      await _timetableRef.doc(result.id).set(result.toMap());
    }
  }

  Future<void> _deleteClass(String id) async {
    if (_uid != null) {
      await _timetableRef.doc(id).delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Timetable'),
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment),
            tooltip: 'Assignments',
            onPressed: () => Navigator.pushReplacementNamed(context, '/'),
          ),
          IconButton(
            icon: const Icon(Icons.timer),
            tooltip: 'Study Timer',
            onPressed: () => Navigator.pushReplacementNamed(context, '/study-timer'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () async {
              final shouldSignOut = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              );
              if (shouldSignOut == true) {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/');
                }
              }
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: List.generate(7, (i) {
                final dayClasses = _classes.where((c) => c.dayOfWeek == i + 1).toList()
                  ..sort((a, b) => a.startTime.hour * 60 + a.startTime.minute - b.startTime.hour * 60 - b.startTime.minute);
                return ExpansionTile(
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _days[i],
                          style: TextStyle(fontWeight: FontWeight.bold, color: _dayColors[i]),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.color_lens),
                        tooltip: 'Pick color',
                        onPressed: () => _pickDayColor(i),
                      ),
                    ],
                  ),
                  children: dayClasses.isEmpty
                      ? [const ListTile(title: Text('No classes'))]
                      : dayClasses.map((c) => ListTile(
                          title: Text(c.className),
                          subtitle: Text('${c.startTime.format(context)} - ${c.endTime.format(context)}' + (c.location != null && c.location!.isNotEmpty ? ' @ ${c.location}' : '')),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteClass(c.id),
                          ),
                        )).toList(),
                );
              }),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addClass,
        child: const Icon(Icons.add),
        tooltip: 'Add Class',
      ),
    );
  }
} 