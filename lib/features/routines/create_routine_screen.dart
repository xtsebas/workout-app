import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/models/exercise_type.dart';
import 'routines_provider.dart';

class CreateRoutineScreen extends ConsumerStatefulWidget {
  const CreateRoutineScreen({super.key});

  @override
  ConsumerState<CreateRoutineScreen> createState() =>
      _CreateRoutineScreenState();
}

class _CreateRoutineScreenState extends ConsumerState<CreateRoutineScreen> {
  final _nameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final name = ref.read(routineBuilderProvider).name;
    _nameCtrl.text = name;
    _nameCtrl.addListener(
        () => ref.read(routineBuilderProvider.notifier).setName(_nameCtrl.text));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final builderState = ref.watch(routineBuilderProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(builderState.isEditing ? 'Edit Routine' : 'New Routine'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Name field
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Routine name'),
          ),
          const SizedBox(height: 28),

          // Weekday selector
          Text(
            'Training days',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _WeekdayPicker(
            selected: builderState.selectedWeekdays,
            onToggle: (d) =>
                ref.read(routineBuilderProvider.notifier).toggleWeekday(d),
          ),
          const SizedBox(height: 28),

          // Exercise slots per day
          if (builderState.selectedWeekdays.isNotEmpty) ...[
            Text(
              'Exercises',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ...(_sortedDays(builderState.selectedWeekdays).map((weekday) =>
                _DaySection(
                  weekday: weekday,
                  slots: builderState.slotsByDay[weekday] ?? [],
                  onAddExercise: () => context.push(
                    '/routines/exercise/search',
                    extra: weekday,
                  ),
                  onRemove: (i) => ref
                      .read(routineBuilderProvider.notifier)
                      .removeSlot(weekday, i),
                ))),
            const SizedBox(height: 24),
          ],

          // Save button
          ElevatedButton(
            onPressed: builderState.isSaving ||
                    builderState.name.trim().isEmpty
                ? null
                : () => _save(context),
            child: builderState.isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(builderState.isEditing ? 'Update routine' : 'Save routine'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    try {
      final notifier = ref.read(routineBuilderProvider.notifier);
      final isEditing = ref.read(routineBuilderProvider).isEditing;
      if (isEditing) {
        await notifier.update();
      } else {
        await notifier.save();
      }
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  List<int> _sortedDays(Set<int> days) => days.toList()..sort();
}

// ── Weekday picker ────────────────────────────────────────────────────────────

class _WeekdayPicker extends StatelessWidget {
  const _WeekdayPicker({required this.selected, required this.onToggle});

  final Set<int> selected;
  final void Function(int) onToggle;

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final weekday = i + 1;
        final isSelected = selected.contains(weekday);
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onToggle(weekday);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? AppColors.accent
                  : AppColors.surface2,
              border: Border.all(
                color: isSelected ? AppColors.accent : AppColors.divider,
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                _labels[i],
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? AppColors.onAccent
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Day section ───────────────────────────────────────────────────────────────

class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.weekday,
    required this.slots,
    required this.onAddExercise,
    required this.onRemove,
  });

  final int weekday;
  final List<SlotConfig> slots;
  final VoidCallback onAddExercise;
  final void Function(int) onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _weekdayLabel(weekday),
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          if (slots.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cardBorder, width: 0.5),
              ),
              child: Text(
                'No exercises yet',
                style: GoogleFonts.outfit(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
            )
          else
            ...slots.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SlotRow(
                    slot: e.value,
                    onRemove: () => onRemove(e.key),
                  ),
                )),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onAddExercise,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.accent.withValues(alpha: 0.3), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add, color: AppColors.accent, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Add exercise',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({required this.slot, required this.onRemove});

  final SlotConfig slot;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(
            _typeIcon(slot.exerciseType),
            color: AppColors.textSecondary,
            size: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.exerciseName,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  _slotLabel(slot),
                  style: GoogleFonts.outfit(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close,
                size: 16, color: AppColors.textSecondary),
            onPressed: onRemove,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  String _slotLabel(SlotConfig s) {
    switch (s.exerciseType) {
      case ExerciseType.weights:
        final reps = s.reps != null ? '× ${s.reps} reps' : '';
        final w = s.weightKg != null ? ' @ ${s.weightKg}kg' : '';
        return '${s.sets} sets $reps$w'.trim();
      case ExerciseType.bodyweight:
        final reps = s.reps != null ? '× ${s.reps} reps' : '';
        return '${s.sets} sets $reps'.trim();
      case ExerciseType.cardio:
      case ExerciseType.timed:
        final dur =
            s.durationSeconds != null ? '× ${s.durationSeconds}s' : '';
        return '${s.sets} sets $dur'.trim();
    }
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

IconData _typeIcon(ExerciseType type) {
  switch (type) {
    case ExerciseType.weights:
      return Icons.fitness_center;
    case ExerciseType.cardio:
      return Icons.directions_run;
    case ExerciseType.timed:
      return Icons.timer_outlined;
    case ExerciseType.bodyweight:
      return Icons.accessibility_new;
  }
}
