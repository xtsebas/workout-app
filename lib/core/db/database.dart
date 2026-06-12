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

  Future<void> setWeightUnit(String unit) =>
      (update(appSettings)..where((t) => t.id.equals(1)))
          .write(AppSettingsCompanion(weightUnit: Value(unit)));
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
