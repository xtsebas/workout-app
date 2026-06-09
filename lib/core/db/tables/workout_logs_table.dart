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
}
