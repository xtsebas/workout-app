import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/db/database.dart';
import '../../core/db/database_provider.dart';

part 'workout_provider.g.dart';

class SetDraft {
  const SetDraft({
    required this.setNumber,
    this.reps,
    this.weightKg,
    this.durationSeconds,
    this.distanceKm,
    this.heartRate,
  });

  final int setNumber;
  final int? reps;
  final double? weightKg;
  final int? durationSeconds;
  final double? distanceKm;
  final int? heartRate;

  SetDraft copyWith({
    int? reps,
    double? weightKg,
    int? durationSeconds,
    double? distanceKm,
    int? heartRate,
  }) =>
      SetDraft(
        setNumber: setNumber,
        reps: reps ?? this.reps,
        weightKg: weightKg ?? this.weightKg,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        distanceKm: distanceKm ?? this.distanceKm,
        heartRate: heartRate ?? this.heartRate,
      );
}

class ActiveWorkoutState {
  const ActiveWorkoutState({
    required this.startedAt,
    this.routineId,
    required this.slots,
    required this.draftSets,
    this.isSaving = false,
  });

  final DateTime startedAt;
  final int? routineId;
  final List<ExerciseSlot> slots;

  /// Maps exerciseSlot.id → list of completed sets for that exercise.
  final Map<int, List<SetDraft>> draftSets;
  final bool isSaving;

  ActiveWorkoutState copyWith({
    Map<int, List<SetDraft>>? draftSets,
    bool? isSaving,
  }) =>
      ActiveWorkoutState(
        startedAt: startedAt,
        routineId: routineId,
        slots: slots,
        draftSets: draftSets ?? this.draftSets,
        isSaving: isSaving ?? this.isSaving,
      );
}

@Riverpod(keepAlive: true)
class ActiveWorkout extends _$ActiveWorkout {
  @override
  ActiveWorkoutState? build() => null;

  void start({required List<ExerciseSlot> slots, int? routineId}) {
    state = ActiveWorkoutState(
      startedAt: DateTime.now(),
      routineId: routineId,
      slots: slots,
      draftSets: {for (final s in slots) s.id: []},
    );
  }

  void addSet(int slotId, SetDraft draft) {
    final current = state;
    if (current == null) return;
    final updated = List<SetDraft>.from(current.draftSets[slotId] ?? [])
      ..add(draft);
    state = current.copyWith(
      draftSets: Map.from(current.draftSets)..[slotId] = updated,
    );
  }

  void removeLastSet(int slotId) {
    final current = state;
    if (current == null) return;
    final updated = List<SetDraft>.from(current.draftSets[slotId] ?? []);
    if (updated.isNotEmpty) updated.removeLast();
    state = current.copyWith(
      draftSets: Map.from(current.draftSets)..[slotId] = updated,
    );
  }

  Future<void> finish() async {
    final current = state;
    if (current == null || current.isSaving) return;
    state = current.copyWith(isSaving: true);

    final db = ref.read(appDatabaseProvider);
    final elapsed = DateTime.now().difference(current.startedAt);

    try {
      await db.transaction(() async {
        final logId = await db.createWorkoutLog(WorkoutLogsCompanion(
          date: Value(DateTime.now()),
          routineId: Value(current.routineId),
          weekday: Value(DateTime.now().weekday),
          durationMinutes: Value(elapsed.inMinutes),
          isCompleted: const Value(true),
        ));

        for (final slot in current.slots) {
          final sets = current.draftSets[slot.id] ?? [];
          for (final draft in sets) {
            await db.insertSetEntry(SetLogEntriesCompanion(
              workoutLogId: Value(logId),
              exerciseSlotOrder: Value(slot.sortOrder),
              exerciseName: Value(slot.exerciseName),
              exerciseType: Value(slot.exerciseType),
              setNumber: Value(draft.setNumber),
              reps: Value(draft.reps),
              weightKg: Value(draft.weightKg),
              durationSeconds: Value(draft.durationSeconds),
              distanceKm: Value(draft.distanceKm),
              heartRate: Value(draft.heartRate),
            ));
          }
        }
      });
      state = null;
    } catch (_) {
      state = current.copyWith(isSaving: false);
      rethrow;
    }
  }

  void discard() => state = null;
}

@riverpod
Future<Map<int, double?>> lastWeightsForExercise(
    Ref ref, String exerciseName, int totalSets) async {
  final db = ref.watch(appDatabaseProvider);
  final sets = await db.getLastSetsForExercise(exerciseName, limit: totalSets);
  final result = <int, double?>{};
  for (final s in sets) {
    result.putIfAbsent(s.setNumber, () => s.weightKg);
  }
  return result;
}
