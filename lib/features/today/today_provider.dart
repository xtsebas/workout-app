import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/db/database.dart';
import '../../core/db/database_provider.dart';

part 'today_provider.g.dart';

class TodayData {
  const TodayData({
    required this.today,
    required this.selectedWeekday,
    this.routine,
    this.routineDay,
    required this.slots,
    required this.logsThisWeek,
    this.lastLog,
  });

  final DateTime today;
  final int selectedWeekday;
  final Routine? routine;
  final RoutineDay? routineDay;
  final List<ExerciseSlot> slots;
  final int logsThisWeek;
  final WorkoutLog? lastLog;
}

@riverpod
Future<WorkoutLog?> incompleteWorkout(Ref ref) =>
    ref.watch(appDatabaseProvider).getIncompleteWorkout();

@riverpod
class WeekdayOverride extends _$WeekdayOverride {
  @override
  int? build() => null;

  void set(int? weekday) => state = weekday;
}

@riverpod
Stream<TodayData> todayData(Ref ref) {
  final override = ref.watch(weekdayOverrideProvider);
  final db = ref.watch(appDatabaseProvider);
  return db.watchLogsThisWeek().asyncMap((logs) async {
    final settings = await db.getSettings();
    final weekday = override ?? DateTime.now().weekday;
    Routine? routine;
    RoutineDay? routineDay;
    List<ExerciseSlot> slots = [];

    if (settings.activeRoutineId != null) {
      routine = await db.getRoutine(settings.activeRoutineId!);
      if (routine != null) {
        routineDay = await db.getDayForWeekday(routine.id, weekday);
        if (routineDay != null) {
          slots = await db.getSlotsForDay(routineDay.id);
        }
      }
    }

    final lastLog = await db.getLastCompletedLog();

    return TodayData(
      today: DateTime.now(),
      selectedWeekday: weekday,
      routine: routine,
      routineDay: routineDay,
      slots: slots,
      logsThisWeek: logs.length,
      lastLog: lastLog,
    );
  });
}
