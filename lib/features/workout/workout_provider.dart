import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/db/database.dart';
import '../../core/db/database_provider.dart';
import '../today/today_provider.dart';

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
    required this.logId,
    required this.startedAt,
    this.routineId,
    required this.slots,
    required this.draftSets,
    this.isSaving = false,
  });

  final int logId;
  final DateTime startedAt;
  final int? routineId;
  final List<ExerciseSlot> slots;
  final Map<int, List<SetDraft>> draftSets;
  final bool isSaving;

  ActiveWorkoutState copyWith({
    Map<int, List<SetDraft>>? draftSets,
    bool? isSaving,
  }) =>
      ActiveWorkoutState(
        logId: logId,
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

  Future<void> start({required List<ExerciseSlot> slots, int? routineId}) async {
    final db = ref.read(appDatabaseProvider);
    final logId = await db.createWorkoutLog(WorkoutLogsCompanion(
      date: Value(DateTime.now()),
      routineId: Value(routineId),
      weekday: Value(DateTime.now().weekday),
      durationMinutes: const Value(0),
      isCompleted: const Value(false),
    ));

    state = ActiveWorkoutState(
      logId: logId,
      startedAt: DateTime.now(),
      routineId: routineId,
      slots: slots,
      draftSets: {for (final s in slots) s.id: []},
    );
  }

  Future<void> restore(WorkoutLog log, List<ExerciseSlot> slots) async {
    final db = ref.read(appDatabaseProvider);
    final entries = await db.getEntriesForLog(log.id);

    final draftSets = <int, List<SetDraft>>{for (final s in slots) s.id: []};
    for (final entry in entries) {
      final slot = slots.where((s) => s.sortOrder == entry.exerciseSlotOrder).firstOrNull;
      if (slot == null) continue;
      draftSets[slot.id]!.add(SetDraft(
        setNumber: entry.setNumber,
        reps: entry.reps,
        weightKg: entry.weightKg,
        durationSeconds: entry.durationSeconds,
        distanceKm: entry.distanceKm,
        heartRate: entry.heartRate,
      ));
    }

    state = ActiveWorkoutState(
      logId: log.id,
      startedAt: log.date,
      routineId: log.routineId,
      slots: slots,
      draftSets: draftSets,
    );
  }

  Future<void> addSet(int slotId, SetDraft draft) async {
    final current = state;
    if (current == null) return;

    final slot = current.slots.firstWhere((s) => s.id == slotId);
    final db = ref.read(appDatabaseProvider);
    await db.insertSetEntry(SetLogEntriesCompanion(
      workoutLogId: Value(current.logId),
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

    final updated = List<SetDraft>.from(current.draftSets[slotId] ?? [])
      ..add(draft);
    state = current.copyWith(
      draftSets: Map.from(current.draftSets)..[slotId] = updated,
    );
  }

  Future<void> removeLastSet(int slotId) async {
    final current = state;
    if (current == null) return;
    final sets = List<SetDraft>.from(current.draftSets[slotId] ?? []);
    if (sets.isEmpty) return;

    final slot = current.slots.firstWhere((s) => s.id == slotId);
    final db = ref.read(appDatabaseProvider);
    await db.deleteLastSetEntry(current.logId, slot.sortOrder);

    sets.removeLast();
    state = current.copyWith(
      draftSets: Map.from(current.draftSets)..[slotId] = sets,
    );
  }

  Future<void> finish() async {
    final current = state;
    if (current == null || current.isSaving) return;
    state = current.copyWith(isSaving: true);

    final db = ref.read(appDatabaseProvider);
    final elapsed = DateTime.now().difference(current.startedAt);

    try {
      await db.completeWorkoutLog(current.logId, elapsed.inMinutes);
      state = null;
      ref.invalidate(incompleteWorkoutProvider);
    } catch (_) {
      state = current.copyWith(isSaving: false);
      rethrow;
    }
  }

  Future<void> discard() async {
    final current = state;
    if (current == null) return;
    final db = ref.read(appDatabaseProvider);
    await db.deleteWorkoutLog(current.logId);
    state = null;
    ref.invalidate(incompleteWorkoutProvider);
  }
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
