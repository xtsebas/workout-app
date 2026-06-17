import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/db/database.dart';
import '../../core/db/database_provider.dart';

part 'today_provider.g.dart';

class TodayData {
  const TodayData({
    required this.today,
    this.routine,
    this.routineDay,
    required this.slots,
    required this.logsThisWeek,
    this.lastLog,
  });

  final DateTime today;
  final Routine? routine;
  final RoutineDay? routineDay;
  final List<ExerciseSlot> slots;
  final int logsThisWeek;
  final WorkoutLog? lastLog;
}

@riverpod
Stream<TodayData> todayData(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchLogsThisWeek().asyncMap((logs) async {
    final settings = await db.getSettings();
    Routine? routine;
    RoutineDay? routineDay;
    List<ExerciseSlot> slots = [];

    if (settings.activeRoutineId != null) {
      routine = await db.getRoutine(settings.activeRoutineId!);
      if (routine != null) {
        final weekday = DateTime.now().weekday;
        routineDay = await db.getDayForWeekday(routine.id, weekday);
        if (routineDay != null) {
          slots = await db.getSlotsForDay(routineDay.id);
        }
      }
    }

    final lastLog = await db.getLastCompletedLog();

    return TodayData(
      today: DateTime.now(),
      routine: routine,
      routineDay: routineDay,
      slots: slots,
      logsThisWeek: logs.length,
      lastLog: lastLog,
    );
  });
}
