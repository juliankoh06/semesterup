import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';
import 'study_timer_providers.dart';
import 'study_session_model.dart';
import 'study_history_page.dart';
import 'notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

final selectedClassProvider = StateProvider<String?>((ref) => null);
final customMinutesProvider = StateProvider<int>((ref) => 25);
final timerControllerProvider = Provider<TimerController>((ref) => TimerController(ref));

class TimerController {
  final Ref ref;
  Timer? _timer;
  Timer? _breakTimer;
  int _breakSeconds = 0;
  bool _onBreak = false;

  TimerController(this.ref);

  void start(BuildContext context) {
    _onBreak = false;
    final minutes = ref.read(customMinutesProvider);
    ref.read(studyTimerProvider.notifier).start(minutes);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      ref.read(studyTimerProvider.notifier).tick();
      final timerState = ref.read(studyTimerProvider);
      if (timerState.remainingSeconds == 0 && timerState.status == TimerStatus.stopped) {
        stop();
        _onStudyComplete(context);
      }
    });
  }

  void pause() {
    if (_onBreak) {
      _breakTimer?.cancel();
    } else {
      ref.read(studyTimerProvider.notifier).pause();
      _timer?.cancel();
    }
  }

  void resume(BuildContext context) {
    if (_onBreak) {
      _startBreakTimer(context);
    } else {
      ref.read(studyTimerProvider.notifier).resume();
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        ref.read(studyTimerProvider.notifier).tick();
        final timerState = ref.read(studyTimerProvider);
        if (timerState.remainingSeconds == 0 && timerState.status == TimerStatus.running) {
          stop();
          _onStudyComplete(context);
        }
      });
    }
  }

  void reset() {
    if (_onBreak) {
      _breakTimer?.cancel();
      _breakSeconds = 0;
      _onBreak = false;
    } else {
      ref.read(studyTimerProvider.notifier).reset();
      _timer?.cancel();
    }
  }

  void stop() {
    ref.read(studyTimerProvider.notifier).stop();
    _timer?.cancel();
    _breakTimer?.cancel();
    _breakSeconds = 0;
    _onBreak = false;
  }

  void _onStudyComplete(BuildContext context) async {
    final timerState = ref.read(studyTimerProvider);
    final selectedClass = ref.read(selectedClassProvider);
    final minutes = timerState.totalMinutes;
    final user = ref.read(authProvider).asData?.value;
    ref.read(studySessionHistoryProvider.notifier).addSession(
      StudySession(
        startTime: DateTime.now(),
        durationMinutes: minutes,
        classOrSubject: selectedClass,
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Study session complete! Attempting to log $minutes min for ${selectedClass ?? 'no subject'}')),
    );
    // Show local notification
    await NotificationService().showStudyTimerNotification(
      title: 'Study Session Complete!',
      body: 'You finished a $minutes-minute session${selectedClass != null ? " for $selectedClass" : ""}.',
    );
    // Prompt for break
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Study Session Complete!'),
        content: const Text('Would you like to take a break?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('skip'),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop('break'),
            child: const Text('Start Break'),
          ),
        ],
      ),
    );
    print('DEBUG: Dialog result: $result');
    if (result == 'break') {
      _startBreakTimer(context);
    }
  }

  void _startBreakTimer(BuildContext context, {int breakMinutes = 5}) {
    _onBreak = true;
    _breakSeconds = breakMinutes * 60;
    _breakTimer?.cancel();
    _showBreakDialog(context);
    _breakTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _breakSeconds--;
      if (_breakSeconds <= 0) {
        _breakTimer?.cancel();
        _onBreak = false;
        _showBreakEndDialog(context);
      }
    });
  }

  void _showBreakDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Timer? updateTimer;
            void update() => setState(() {});
            updateTimer = Timer.periodic(const Duration(seconds: 1), (_) => update());
            return AlertDialog(
              title: const Text('Break Time!'),
              content: Text('Break remaining: ${(_breakSeconds ~/ 60).toString().padLeft(2, '0')}:${(_breakSeconds % 60).toString().padLeft(2, '0')}'),
              actions: [
                TextButton(
                  onPressed: () {
                    updateTimer?.cancel();
                    _breakTimer?.cancel();
                    _onBreak = false;
                    Navigator.of(context).pop();
                  },
                  child: const Text('Skip Break'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showBreakEndDialog(BuildContext context) {
    // Show notification for break end
    NotificationService().showStudyTimerNotification(
      title: 'Break Complete!',
      body: 'Your break is over. Ready to start another study session?',
    );
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Break Complete!'),
        content: const Text('Ready to start another study session?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}


class StudyTimerPage extends ConsumerStatefulWidget {
  const StudyTimerPage({super.key});

  @override
  ConsumerState<StudyTimerPage> createState() => _StudyTimerPageState();
}

class _StudyTimerPageState extends ConsumerState<StudyTimerPage> {
  final TextEditingController _minutesController = TextEditingController(text: '25');

  @override
  void dispose() {
    _minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classes = ref.watch(studyClassesProvider);
    final selectedClass = ref.watch(selectedClassProvider);
    final timerState = ref.watch(studyTimerProvider);
    final timerController = ref.read(timerControllerProvider);
    final customMinutes = ref.watch(customMinutesProvider);

    String _formatTime(int totalSeconds) {
      final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
      final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
      return "$minutes:$seconds";
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Study Timer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment),
            tooltip: 'Assignments',
            onPressed: () => Navigator.pushReplacementNamed(context, '/'),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Timetable',
            onPressed: () => Navigator.pushReplacementNamed(context, '/timetable'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/');
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: selectedClass,
                    hint: const Text('Select subject (Optional)'),
                    items: classes.map((c) => DropdownMenuItem<String>(
                      value: c.name,
                      child: Text(c.name),
                    )).toList(),
                    onChanged: (val) => ref.read(selectedClassProvider.notifier).state = val,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Add new class/subject',
                  onPressed: () async {
                    final controller = TextEditingController();
                    final result = await showDialog<String>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Add Class/Subject'),
                        content: TextField(
                          controller: controller,
                          autofocus: true,
                          decoration: const InputDecoration(labelText: 'Class/Subject name'),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
                            child: const Text('Add'),
                          ),
                        ],
                      ),
                    );
                    if (result != null && result.isNotEmpty) {
                      await ref.read(studyClassesProvider.notifier).addClass(result);
                      ref.read(selectedClassProvider.notifier).state = result;
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text('Set Study Time:'),
                  const SizedBox(width: 12),
                  ...[15, 25, 30, 45, 60].map((min) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: customMinutes == min ? Colors.blue : Colors.grey[200],
                        foregroundColor: customMinutes == min ? Colors.white : Colors.black,
                        minimumSize: const Size(36, 36),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () {
                        ref.read(customMinutesProvider.notifier).state = min;
                        _minutesController.text = min.toString();
                      },
                      child: Text('$min'),
                    ),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 36),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: CircularProgressIndicator(
                      value: timerState.status == TimerStatus.running || timerState.status == TimerStatus.paused
                          ? timerState.remainingSeconds / (timerState.totalMinutes * 60)
                          : 1.0,
                      strokeWidth: 10,
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      if (timerState.status != TimerStatus.running) {
                        final controller = TextEditingController(text: timerState.totalMinutes.toString());
                        final result = await showDialog<int>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Set Timer'),
                            content: TextField(
                              controller: controller,
                              autofocus: true,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Minutes', suffixText: 'min'),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  final v = int.tryParse(controller.text.trim());
                                  if (v != null && v > 0) {
                                    Navigator.of(context).pop(v);
                                  }
                                },
                                child: const Text('Set'),
                              ),
                            ],
                          ),
                        );
                        if (result != null && result > 0) {
                          ref.read(customMinutesProvider.notifier).state = result;
                          _minutesController.text = result.toString();
                        }
                      }
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _formatTime(timerState.remainingSeconds),
                          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          timerController._onBreak ? 'Break' : 'Study',
                          style: TextStyle(
                            color: timerController._onBreak ? Colors.green : Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (timerState.status != TimerStatus.running)
                          const Text('Tap to set time', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (timerState.status == TimerStatus.stopped || timerState.status == TimerStatus.paused)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start'),
                    onPressed: () => timerController.start(context),
                  ),
                if (timerState.status == TimerStatus.running)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause'),
                    onPressed: () => timerController.pause(),
                  ),
                const SizedBox(width: 16),
                if (timerState.status == TimerStatus.paused)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Resume'),
                    onPressed: () => timerController.resume(context),
                  ),
                if (timerState.status != TimerStatus.stopped)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.stop),
                    label: const Text('Reset'),
                    onPressed: () => timerController.reset(),
                  ),
              ],
            ),
            const Spacer(),
            ElevatedButton.icon(
              icon: const Icon(Icons.history),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StudyHistoryPage()),
                );
              },
              label: const Text('View Study History'),
            ),
          ],
        ),
      ),
    );
  }
}
