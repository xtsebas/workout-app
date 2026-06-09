import 'package:drift/drift.dart';

import '../../../shared/models/exercise_type.dart';
import 'routine_days_table.dart';

@DataClassName('ExerciseSlot')
class ExerciseSlots extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get routineDayId =>
      integer().references(RoutineDays, #id, onDelete: KeyAction.cascade)();
  IntColumn get sortOrder => integer()();
  IntColumn get wgerExerciseId => integer().nullable()();
  TextColumn get exerciseName => text()();
  TextColumn get exerciseType => textEnum<ExerciseType>()();
  IntColumn get sets => integer()();
  IntColumn get reps => integer().nullable()();
  IntColumn get durationSeconds => integer().nullable()();
  RealColumn get weightKg => real().nullable()();
  TextColumn get notes => text().nullable()();
}
