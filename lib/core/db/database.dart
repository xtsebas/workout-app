import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import '../../shared/models/exercise_type.dart';
import 'tables/app_settings_table.dart';
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
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

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

  // Exercise cache
  Future<CachedExercise?> getCachedExercise(int wgerId) =>
      (select(exerciseCache)..where((t) => t.wgerId.equals(wgerId)))
          .getSingleOrNull();

  Future<void> upsertCachedExercise(ExerciseCacheCompanion entry) =>
      into(exerciseCache).insertOnConflictUpdate(entry);
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'workout_app.sqlite'));

    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    if (Platform.isIOS || Platform.isMacOS) {
      sqlite3.tempDirectory = (await getTemporaryDirectory()).path;
    }

    return NativeDatabase.createInBackground(file);
  });
}
