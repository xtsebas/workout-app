import 'package:drift/drift.dart';

import 'routines_table.dart';

@DataClassName('RoutineDay')
class RoutineDays extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get routineId =>
      integer().references(Routines, #id, onDelete: KeyAction.cascade)();

  /// 1 = Monday ... 7 = Sunday
  IntColumn get weekday => integer()();
  TextColumn get label => text()();
}
