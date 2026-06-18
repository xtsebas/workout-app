import 'package:drift/drift.dart';

import '../../../shared/models/exercise_type.dart';

@DataClassName('CustomExercise')
class CustomExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  TextColumn get exerciseType => textEnum<ExerciseType>()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
