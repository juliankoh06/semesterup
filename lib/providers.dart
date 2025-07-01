import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'assignment_repository.dart';
import 'auth_provider.dart';

final assignmentRepoProvider = Provider((ref) => AssignmentRepository());

final assignmentsProvider = StreamProvider((ref) {
  final repo = ref.read(assignmentRepoProvider);
  final user = ref.watch(authProvider).value;
  if (user == null) return const Stream.empty();
  return repo.getAssignments(user.uid);
});

