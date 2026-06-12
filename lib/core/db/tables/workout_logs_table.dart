import 'package:drift/drift.dart';

@DataClassName('WorkoutLog')
class WorkoutLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime()();
  IntColumn get routineId => integer().nullable()();

  /// 1 = Monday ... 7 = Sunday
  IntColumn get weekday => integer()();
  IntColumn get durationMinutes => integer().withDefault(const Constant(0))();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();

  /// Sync-ready columns (used by the future Cloud Sync phase).
  TextColumn get remoteId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
}
