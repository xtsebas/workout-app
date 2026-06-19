import 'package:drift/drift.dart';

import '../../shared/models/exercise_type.dart';
import 'connection/connection.dart';
import 'tables/app_settings_table.dart';
import 'tables/custom_exercises_table.dart';
import 'tables/exercise_cache_table.dart';
import 'tables/exercise_slots_table.dart';
import 'tables/routine_days_table.dart';
import 'tables/routines_table.dart';
import 'tables/set_log_entries_table.dart';
import 'tables/workout_logs_table.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  AppSettings,
  Routines,
  RoutineDays,
  ExerciseSlots,
  WorkoutLogs,
  SetLogEntries,
  ExerciseCache,
  CustomExercises,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await into(appSettings).insert(
            AppSettingsCompanion.insert(id: const Value(1)),
          );
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(appSettings, appSettings.supabaseUserId);

            await m.addColumn(routines, routines.remoteId);
            await m.addColumn(routines, routines.updatedAt);
            await m.addColumn(routines, routines.isSynced);

            await m.addColumn(routineDays, routineDays.remoteId);
            await m.addColumn(routineDays, routineDays.updatedAt);
            await m.addColumn(routineDays, routineDays.isSynced);

            await m.addColumn(exerciseSlots, exerciseSlots.remoteId);
            await m.addColumn(exerciseSlots, exerciseSlots.updatedAt);
            await m.addColumn(exerciseSlots, exerciseSlots.isSynced);

            await m.addColumn(workoutLogs, workoutLogs.remoteId);
            await m.addColumn(workoutLogs, workoutLogs.updatedAt);
            await m.addColumn(workoutLogs, workoutLogs.isSynced);

            await m.addColumn(setLogEntries, setLogEntries.remoteId);
            await m.addColumn(setLogEntries, setLogEntries.updatedAt);
            await m.addColumn(setLogEntries, setLogEntries.isSynced);
          }
          if (from < 3) {
            await m.createTable(customExercises);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Stream<AppSettingsData> watchSettings() =>
      (select(appSettings)..where((t) => t.id.equals(1))).watchSingle();

  Future<AppSettingsData> getSettings() =>
      (select(appSettings)..where((t) => t.id.equals(1))).getSingle();

  Future<void> setWeightUnit(String unit) =>
      (update(appSettings)..where((t) => t.id.equals(1)))
          .write(AppSettingsCompanion(weightUnit: Value(unit)));

  Future<void> setActiveRoutine(int? routineId) =>
      (update(appSettings)..where((t) => t.id.equals(1)))
          .write(AppSettingsCompanion(activeRoutineId: Value(routineId)));

  // Routines
  Future<Routine?> getRoutine(int id) =>
      (select(routines)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<List<Routine>> watchAllRoutines() =>
      (select(routines)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  // Routine days & slots
  Future<RoutineDay?> getDayForWeekday(int routineId, int weekday) =>
      (select(routineDays)
            ..where((t) =>
                t.routineId.equals(routineId) & t.weekday.equals(weekday)))
          .getSingleOrNull();

  Future<List<ExerciseSlot>> getSlotsForDay(int routineDayId) =>
      (select(exerciseSlots)
            ..where((t) => t.routineDayId.equals(routineDayId))
            ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
          .get();

  // Workout logs
  Stream<List<WorkoutLog>> watchLogsThisWeek() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = DateTime(monday.year, monday.month, monday.day);
    return (select(workoutLogs)
          ..where((t) => t.date.isBiggerOrEqualValue(weekStart))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .watch();
  }

  Future<WorkoutLog?> getLastCompletedLog() =>
      (select(workoutLogs)
            ..where((t) => t.isCompleted.equals(true))
            ..orderBy([(t) => OrderingTerm.desc(t.date)])
            ..limit(1))
          .getSingleOrNull();

  Future<int> createWorkoutLog(WorkoutLogsCompanion log) =>
      into(workoutLogs).insert(log);

  Future<void> insertSetEntry(SetLogEntriesCompanion entry) =>
      into(setLogEntries).insert(entry);

  Future<List<SetLogEntry>> getLastSetsForExercise(
    String exerciseName, {
    int limit = 10,
  }) async {
    final recentLogs = await (select(workoutLogs)
          ..where((t) => t.isCompleted.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(5))
        .get();
    if (recentLogs.isEmpty) return [];
    final ids = recentLogs.map((l) => l.id).toList();
    return (select(setLogEntries)
          ..where((t) =>
              t.workoutLogId.isIn(ids) & t.exerciseName.equals(exerciseName))
          ..orderBy([
            (t) => OrderingTerm.desc(t.workoutLogId),
            (t) => OrderingTerm.asc(t.setNumber),
          ])
          ..limit(limit))
        .get();
  }

  // Progress queries
  Future<List<WorkoutLog>> getLogsForMonth(int year, int month) {
    final start = DateTime(year, month);
    final end = DateTime(year, month + 1);
    return (select(workoutLogs)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(start) &
              t.date.isSmallerThanValue(end) &
              t.isCompleted.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }

  Future<List<SetLogEntry>> getEntriesForLog(int logId) =>
      (select(setLogEntries)
            ..where((t) => t.workoutLogId.equals(logId))
            ..orderBy([
              (t) => OrderingTerm.asc(t.exerciseSlotOrder),
              (t) => OrderingTerm.asc(t.setNumber),
            ]))
          .get();

  Future<int> countCompletedLogs() async {
    final count = countAll();
    final query = selectOnly(workoutLogs)
      ..addColumns([count])
      ..where(workoutLogs.isCompleted.equals(true));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<int> currentStreak() async {
    final logs = await (select(workoutLogs)
          ..where((t) => t.isCompleted.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
    if (logs.isEmpty) return 0;

    int streak = 0;
    var expected = DateTime.now();
    expected = DateTime(expected.year, expected.month, expected.day);

    for (final log in logs) {
      final logDate = DateTime(log.date.year, log.date.month, log.date.day);
      if (logDate == expected) {
        streak++;
        expected = expected.subtract(const Duration(days: 1));
      } else if (logDate == expected.subtract(const Duration(days: 1))) {
        expected = logDate;
        streak++;
        expected = expected.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  Future<List<String>> getDistinctExerciseNames() async {
    final query = selectOnly(setLogEntries, distinct: true)
      ..addColumns([setLogEntries.exerciseName])
      ..orderBy([OrderingTerm.asc(setLogEntries.exerciseName)]);
    final rows = await query.get();
    return rows.map((r) => r.read(setLogEntries.exerciseName)!).toList();
  }

  Future<List<({DateTime date, double maxWeight, int bestReps, double totalVolume})>>
      getExerciseHistory(String exerciseName) async {
    final entries = await (select(setLogEntries)
          ..where((t) => t.exerciseName.equals(exerciseName)))
        .join([
      innerJoin(workoutLogs, workoutLogs.id.equalsExp(setLogEntries.workoutLogId)),
    ]).get();

    final byDate = <DateTime, List<TypedResult>>{};
    for (final row in entries) {
      final log = row.readTable(workoutLogs);
      final date = DateTime(log.date.year, log.date.month, log.date.day);
      byDate.putIfAbsent(date, () => []).add(row);
    }

    final result = <({DateTime date, double maxWeight, int bestReps, double totalVolume})>[];
    final sortedDates = byDate.keys.toList()..sort();
    for (final date in sortedDates) {
      double maxWeight = 0;
      int bestReps = 0;
      double totalVolume = 0;
      for (final row in byDate[date]!) {
        final entry = row.readTable(setLogEntries);
        final w = entry.weightKg ?? 0;
        final r = entry.reps ?? 0;
        if (w > maxWeight) maxWeight = w;
        if (r > bestReps) bestReps = r;
        totalVolume += w * r;
      }
      result.add((date: date, maxWeight: maxWeight, bestReps: bestReps, totalVolume: totalVolume));
    }
    return result;
  }

  // Routine CRUD
  Future<int> insertRoutine(RoutinesCompanion routine) =>
      into(routines).insert(routine);

  Future<void> updateRoutine(int id, RoutinesCompanion data) =>
      (update(routines)..where((t) => t.id.equals(id))).write(data);

  Future<void> deleteRoutine(int id) =>
      (delete(routines)..where((t) => t.id.equals(id))).go();

  Future<void> deleteRoutineDays(int routineId) =>
      (delete(routineDays)..where((t) => t.routineId.equals(routineId))).go();

  Future<int> insertRoutineDay(RoutineDaysCompanion day) =>
      into(routineDays).insert(day);

  Future<List<RoutineDay>> getRoutineDays(int routineId) =>
      (select(routineDays)
            ..where((t) => t.routineId.equals(routineId))
            ..orderBy([(t) => OrderingTerm.asc(t.weekday)]))
          .get();

  Future<int> insertExerciseSlot(ExerciseSlotsCompanion slot) =>
      into(exerciseSlots).insert(slot);

  // Sync methods
  Future<List<WorkoutLog>> getUnsyncedLogs() =>
      (select(workoutLogs)
            ..where((t) => t.isSynced.equals(false) & t.isCompleted.equals(true)))
          .get();

  Future<void> markLogSynced(int id, String remoteId) =>
      (update(workoutLogs)..where((t) => t.id.equals(id))).write(
        WorkoutLogsCompanion(
          isSynced: const Value(true),
          remoteId: Value(remoteId),
        ),
      );

  Future<List<SetLogEntry>> getUnsyncedEntries() async {
    final syncedLogIds = (await getUnsyncedLogs()).map((l) => l.id).toList();
    if (syncedLogIds.isEmpty) {
      return (select(setLogEntries)..where((t) => t.isSynced.equals(false))).get();
    }
    return (select(setLogEntries)
          ..where((t) =>
              t.isSynced.equals(false) & t.workoutLogId.isNotIn(syncedLogIds)))
        .get();
  }

  Future<List<SetLogEntry>> getEntriesForLogSync(int logId) =>
      (select(setLogEntries)..where((t) => t.workoutLogId.equals(logId))).get();

  Future<void> markEntrySynced(int id, String remoteId) =>
      (update(setLogEntries)..where((t) => t.id.equals(id))).write(
        SetLogEntriesCompanion(
          isSynced: const Value(true),
          remoteId: Value(remoteId),
        ),
      );

  // Custom exercises
  Future<int> insertCustomExercise(CustomExercisesCompanion exercise) =>
      into(customExercises).insertOnConflictUpdate(exercise);

  Future<List<CustomExercise>> searchCustomExercises(String query) {
    final q = '%${query.toLowerCase()}%';
    return (select(customExercises)
          ..where((t) => t.name.lower().like(q))
          ..limit(20))
        .get();
  }

  // Exercise cache
  Future<CachedExercise?> getCachedExercise(int wgerId) =>
      (select(exerciseCache)..where((t) => t.wgerId.equals(wgerId)))
          .getSingleOrNull();

  Future<void> upsertCachedExercise(ExerciseCacheCompanion entry) =>
      into(exerciseCache).insertOnConflictUpdate(entry);
}

