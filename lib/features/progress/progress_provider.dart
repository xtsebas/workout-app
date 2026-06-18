import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/db/database.dart';
import '../../core/db/database_provider.dart';

part 'progress_provider.g.dart';

class MonthStats {
  const MonthStats({
    required this.logs,
    required this.workoutDates,
    required this.totalSessions,
    required this.totalVolumeKg,
    required this.streak,
  });

  final List<WorkoutLog> logs;
  final Set<int> workoutDates;
  final int totalSessions;
  final double totalVolumeKg;
  final int streak;
}

@riverpod
Future<MonthStats> monthStats(Ref ref, int year, int month) async {
  final db = ref.watch(appDatabaseProvider);
  final logs = await db.getLogsForMonth(year, month);

  final workoutDates = <int>{};
  for (final log in logs) {
    workoutDates.add(log.date.day);
  }

  double totalVolume = 0;
  for (final log in logs) {
    final entries = await db.getEntriesForLog(log.id);
    for (final e in entries) {
      if (e.weightKg != null && e.reps != null) {
        totalVolume += e.weightKg! * e.reps!;
      }
    }
  }

  final streak = await db.currentStreak();

  return MonthStats(
    logs: logs,
    workoutDates: workoutDates,
    totalSessions: logs.length,
    totalVolumeKg: totalVolume,
    streak: streak,
  );
}

@riverpod
Future<List<SetLogEntry>> logEntries(Ref ref, int logId) =>
    ref.watch(appDatabaseProvider).getEntriesForLog(logId);

@riverpod
Future<List<String>> exerciseNames(Ref ref) =>
    ref.watch(appDatabaseProvider).getDistinctExerciseNames();

@riverpod
Future<List<({DateTime date, double maxWeight, int bestReps, double totalVolume})>>
    exerciseHistory(Ref ref, String exerciseName) =>
        ref.watch(appDatabaseProvider).getExerciseHistory(exerciseName);
