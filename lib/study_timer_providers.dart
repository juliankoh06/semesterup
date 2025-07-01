import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'study_session_model.dart';
import 'auth_provider.dart';

// Holds the added subjects
final studyClassesProvider = StateNotifierProvider<StudyClassesNotifier, List<StudyClass>>((ref) {
  final user = ref.watch(authProvider).asData?.value;
  return StudyClassesNotifier(user);
});

class StudyClassesNotifier extends StateNotifier<List<StudyClass>> {
  final User? user;
  final _firestore = FirebaseFirestore.instance;
  StudyClassesNotifier(this.user) : super([]) {
    _init();
  }

  void _init() {
    if (user == null) return;
    _firestore
      .collection('users/${user!.uid}/study_classes')
      .snapshots()
      .listen((snapshot) {
        final classes = snapshot.docs.map((doc) => StudyClass(doc['name'] as String)).toList();
        state = classes;
      });
  }

  Future<void> addClass(String name) async {
    if (user == null) return;
    if (!state.any((c) => c.name == name)) {
      // Add to Firestore
      await _firestore.collection('users/${user!.uid}/study_classes').add({'name': name});
      // Local state will update via snapshot listener
    }
  }

  Future<void> deleteClass(String name) async {
    if (user == null) return;
    final query = await _firestore
        .collection('users/${user!.uid}/study_classes')
        .where('name', isEqualTo: name)
        .get();
    for (var doc in query.docs) {
      await doc.reference.delete();
    }
    // Local state will update via snapshot listener
  }

  Future<void> renameClass(String oldName, String newName) async {
    if (user == null) return;
    final query = await _firestore
        .collection('users/${user!.uid}/study_classes')
        .where('name', isEqualTo: oldName)
        .get();
    for (var doc in query.docs) {
      await doc.reference.update({'name': newName});
    }
  }
}


// Holds the study timer state
enum TimerStatus { stopped, running, paused }

class StudyTimerState {
  final int totalMinutes;
  final int remainingSeconds;
  final TimerStatus status;
  StudyTimerState({required this.totalMinutes, required this.remainingSeconds, required this.status});
}

final studyTimerProvider = StateNotifierProvider<StudyTimerNotifier, StudyTimerState>((ref) => StudyTimerNotifier());

class StudyTimerNotifier extends StateNotifier<StudyTimerState> {
  StudyTimerNotifier() : super(StudyTimerState(totalMinutes: 25, remainingSeconds: 1500, status: TimerStatus.stopped));

  int? _pausedSeconds;

  void start(int minutes) {
    state = StudyTimerState(
      totalMinutes: minutes,
      remainingSeconds: minutes * 60,
      status: TimerStatus.running,
    );
    _pausedSeconds = null;
  }

  void tick() {
    if (state.status == TimerStatus.running && state.remainingSeconds > 0) {
      state = StudyTimerState(
        totalMinutes: state.totalMinutes,
        remainingSeconds: state.remainingSeconds - 1,
        status: state.remainingSeconds - 1 == 0 ? TimerStatus.stopped : TimerStatus.running,
      );
    }
  }

  void pause() {
    if (state.status == TimerStatus.running) {
      _pausedSeconds = state.remainingSeconds;
      state = StudyTimerState(
        totalMinutes: state.totalMinutes,
        remainingSeconds: state.remainingSeconds,
        status: TimerStatus.paused,
      );
    }
  }

  void resume() {
    if (state.status == TimerStatus.paused && _pausedSeconds != null) {
      state = StudyTimerState(
        totalMinutes: state.totalMinutes,
        remainingSeconds: _pausedSeconds!,
        status: TimerStatus.running,
      );
    }
  }

  void reset() {
    state = StudyTimerState(
      totalMinutes: state.totalMinutes,
      remainingSeconds: state.totalMinutes * 60,
      status: TimerStatus.stopped,
    );
    _pausedSeconds = null;
  }

  void stop() {
    state = StudyTimerState(
      totalMinutes: state.totalMinutes,
      remainingSeconds: state.totalMinutes * 60,
      status: TimerStatus.stopped,
    );
    _pausedSeconds = null;
  }
}


// Holds the session history
final studySessionHistoryProvider = StateNotifierProvider<StudySessionHistoryNotifier, List<StudySession>>((ref) {
  final user = ref.watch(authProvider).asData?.value;
  return StudySessionHistoryNotifier(user);
});

class StudySessionHistoryNotifier extends StateNotifier<List<StudySession>> {
  final User? user;
  final _firestore = FirebaseFirestore.instance;

  StudySessionHistoryNotifier(this.user) : super([]) {
    _init();
  }

  void _init() {
    if (user == null) return;
    _firestore
        .collection('users/${user!.uid}/study_sessions')
        .orderBy('startTime', descending: true)
        .snapshots()
        .listen((snapshot) {
      final sessions = snapshot.docs.map((doc) {
        return StudySession(
          startTime: (doc['startTime'] as Timestamp).toDate(),
          durationMinutes: doc['durationMinutes'] as int,
          classOrSubject: doc['classOrSubject'] as String?,
        );
      }).toList();
      state = sessions;
    });
  }

  Future<void> addSession(StudySession session) async {
    if (user == null) {
      state = [session, ...state];
      return;
    }
    try {
      await _firestore.collection('users/${user!.uid}/study_sessions').add({
        'startTime': session.startTime,
        'durationMinutes': session.durationMinutes,
        'classOrSubject': session.classOrSubject,
      });
    } catch (e) {
      print('ERROR: Failed to write session to Firestore: $e');
    }
    // Local state will update via snapshot listener
  }
}