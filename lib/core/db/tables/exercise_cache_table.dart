import 'package:drift/drift.dart';

/// Locally cached exercise data fetched from the WGER API.
@DataClassName('CachedExercise')
class ExerciseCache extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get wgerId => integer().unique()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get muscleGroup => text().nullable()();
  DateTimeColumn get cachedAt => dateTime()();
}
