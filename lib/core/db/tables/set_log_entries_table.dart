import 'package:drift/drift.dart';

import '../../../shared/models/exercise_type.dart';
import 'workout_logs_table.dart';

@DataClassName('SetLogEntry')
class SetLogEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutLogId =>
      integer().references(WorkoutLogs, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseSlotOrder => integer()();
  TextColumn get exerciseName => text()();
  TextColumn get exerciseType => textEnum<ExerciseType>()();
  IntColumn get setNumber => integer()();

  // weights / bodyweight
  IntColumn get reps => integer().nullable()();
  RealColumn get weightKg => real().nullable()();

  // cardio / timed
  IntColumn get durationSeconds => integer().nullable()();
  RealColumn get distanceKm => real().nullable()();
  IntColumn get heartRate => integer().nullable()();
}
