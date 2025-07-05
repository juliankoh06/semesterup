import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'study_timer_providers.dart';


class StudyHistoryPage extends ConsumerWidget {
  const StudyHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(studySessionHistoryProvider);
    // Calculate last 7 days summary
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final lastSevenDaysSessions = sessions.where((s) => s.startTime.isAfter(sevenDaysAgo)).toList();
    final Map<String, int> subjectTotals = {};
    for (var s in lastSevenDaysSessions) {
      final subject = s.classOrSubject ?? 'No subject';
      subjectTotals[subject] = (subjectTotals[subject] ?? 0) + s.durationMinutes;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Study History')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subjectTotals.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Last 7 Days (per Subject):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: subjectTotals.entries.map((e) {
                  final hours = e.value ~/ 60;
                  final minutes = e.value % 60;
                  final timeText = hours > 0 
                    ? '$hours hour${hours > 1 ? 's' : ''} ${minutes > 0 ? '$minutes min' : ''}'
                    : '${minutes} min';
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text(
                      '${e.key}: $timeText',
                      style: const TextStyle(
                        fontSize: 20, 
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(),
          ],
          Expanded(
            child: sessions.isEmpty 
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No study sessions yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Complete a study timer to see your history here',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                      final session = sessions[index];
                      final hours = session.durationMinutes ~/ 60;
                      final minutes = session.durationMinutes % 60;
                      final timeText = hours > 0 
                        ? '$hours hour${hours > 1 ? 's' : ''} ${minutes > 0 ? '$minutes min' : ''}'
                        : '${minutes} min';
                      
                      return ListTile(
                        title: Text(
                          session.classOrSubject ?? 'No subject',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        subtitle: Text(
                          'Duration: $timeText\n${session.startTime.toString().substring(0, 16)}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      );
                  },
              ), // ListView.builder
            ), // Expanded
        ],
      ), // Column
    ); // Scaffold
  }
}
