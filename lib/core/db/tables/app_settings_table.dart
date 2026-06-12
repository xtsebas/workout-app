import 'package:drift/drift.dart';

/// Singleton row (id always 1) holding app-wide preferences.
@DataClassName('AppSettingsData')
class AppSettings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get weightUnit => text().withDefault(const Constant('kg'))();
  IntColumn get activeRoutineId => integer().nullable()();

  /// Supabase auth user id, set after sign-in.
  TextColumn get supabaseUserId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
