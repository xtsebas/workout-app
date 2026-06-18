import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/db/database.dart';
import '../../core/db/database_provider.dart';
import '../../shared/models/exercise_type.dart';
import '../today/today_provider.dart';

part 'routines_provider.g.dart';

// ── SlotConfig ───────────────────────────────────────────────────────────────

class SlotConfig {
  const SlotConfig({
    required this.exerciseName,
    this.wgerExerciseId,
    required this.exerciseType,
    required this.sets,
    this.reps,
    this.durationSeconds,
    this.weightKg,
  });

  final String exerciseName;
  final int? wgerExerciseId;
  final ExerciseType exerciseType;
  final int sets;
  final int? reps;
  final int? durationSeconds;
  final double? weightKg;
}

// ── RoutineBuilderState ───────────────────────────────────────────────────────

class RoutineBuilderState {
  const RoutineBuilderState({
    this.name = '',
    this.selectedWeekdays = const {},
    this.slotsByDay = const {},
    this.isSaving = false,
  });

  final String name;
  final Set<int> selectedWeekdays;
  final Map<int, List<SlotConfig>> slotsByDay;
  final bool isSaving;

  RoutineBuilderState copyWith({
    String? name,
    Set<int>? selectedWeekdays,
    Map<int, List<SlotConfig>>? slotsByDay,
    bool? isSaving,
  }) =>
      RoutineBuilderState(
        name: name ?? this.name,
        selectedWeekdays: selectedWeekdays ?? this.selectedWeekdays,
        slotsByDay: slotsByDay ?? this.slotsByDay,
        isSaving: isSaving ?? this.isSaving,
      );
}

// ── RoutineBuilder notifier ───────────────────────────────────────────────────

@riverpod
class RoutineBuilder extends _$RoutineBuilder {
  @override
  RoutineBuilderState build() => const RoutineBuilderState();

  void setName(String name) => state = state.copyWith(name: name);

  void toggleWeekday(int weekday) {
    final days = Set<int>.from(state.selectedWeekdays);
    if (days.contains(weekday)) {
      days.remove(weekday);
      final slots = Map<int, List<SlotConfig>>.from(state.slotsByDay)
        ..remove(weekday);
      state = state.copyWith(selectedWeekdays: days, slotsByDay: slots);
    } else {
      days.add(weekday);
      state = state.copyWith(selectedWeekdays: days);
    }
  }

  void addSlot(int weekday, SlotConfig slot) {
    final slots = Map<int, List<SlotConfig>>.from(state.slotsByDay);
    slots[weekday] = [...(slots[weekday] ?? []), slot];
    state = state.copyWith(slotsByDay: slots);
  }

  void removeSlot(int weekday, int index) {
    final slots = Map<int, List<SlotConfig>>.from(state.slotsByDay);
    final list = List<SlotConfig>.from(slots[weekday] ?? []);
    if (index < list.length) list.removeAt(index);
    slots[weekday] = list;
    state = state.copyWith(slotsByDay: slots);
  }

  Future<void> save() async {
    if (state.name.trim().isEmpty || state.isSaving) return;
    state = state.copyWith(isSaving: true);

    final db = ref.read(appDatabaseProvider);
    try {
      await db.transaction(() async {
        final routineId = await db.insertRoutine(
          RoutinesCompanion(name: Value(state.name.trim())),
        );
        final sortedDays = state.selectedWeekdays.toList()..sort();
        for (final weekday in sortedDays) {
          final dayId = await db.insertRoutineDay(RoutineDaysCompanion(
            routineId: Value(routineId),
            weekday: Value(weekday),
            label: Value(_weekdayLabel(weekday)),
          ));
          final slots = state.slotsByDay[weekday] ?? [];
          for (var i = 0; i < slots.length; i++) {
            final s = slots[i];
            await db.insertExerciseSlot(ExerciseSlotsCompanion(
              routineDayId: Value(dayId),
              sortOrder: Value(i),
              wgerExerciseId: Value(s.wgerExerciseId),
              exerciseName: Value(s.exerciseName),
              exerciseType: Value(s.exerciseType),
              sets: Value(s.sets),
              reps: Value(s.reps),
              durationSeconds: Value(s.durationSeconds),
              weightKg: Value(s.weightKg),
            ));
          }
        }
      });
      state = const RoutineBuilderState();
    } catch (_) {
      state = state.copyWith(isSaving: false);
      rethrow;
    }
  }

  void reset() => state = const RoutineBuilderState();
}

// ── All routines stream ───────────────────────────────────────────────────────

@riverpod
Stream<List<Routine>> allRoutines(Ref ref) =>
    ref.watch(appDatabaseProvider).watchAllRoutines();

// ── Active routine management ─────────────────────────────────────────────────

@riverpod
class ActiveRoutineNotifier extends _$ActiveRoutineNotifier {
  @override
  Future<int?> build() async {
    final settings = await ref.watch(appDatabaseProvider).getSettings();
    return settings.activeRoutineId;
  }

  Future<void> setActive(int? routineId) async {
    await ref.read(appDatabaseProvider).setActiveRoutine(routineId);
    state = AsyncData(routineId);
    ref.invalidate(todayDataProvider);
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _weekdayLabel(int weekday) {
  const labels = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];
  return labels[(weekday - 1).clamp(0, 6)];
}
