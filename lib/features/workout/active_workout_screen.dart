import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/db/database.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/exercise_type.dart';
import '../../shared/models/set_type.dart';
import 'workout_provider.dart';

class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  ConsumerState<ActiveWorkoutScreen> createState() =>
      _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _timerLabel(DateTime startedAt) {
    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    final h = elapsed ~/ 3600;
    final m = (elapsed % 3600) ~/ 60;
    final s = elapsed % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final workoutState = ref.watch(activeWorkoutProvider);

    if (workoutState == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _confirmDiscard(context),
        ),
        title: Text(
          _timerLabel(workoutState.startedAt),
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            letterSpacing: 1,
          ),
        ),
        actions: [
          TextButton(
            onPressed: workoutState.isSaving
                ? null
                : () => _confirmDiscard(context),
            child: Text(
              'Discard',
              style: GoogleFonts.outfit(
                color: AppColors.danger,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: workoutState.slots.isEmpty
            ? _EmptyWorkoutBody(isSaving: workoutState.isSaving)
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                itemCount: workoutState.slots.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final slot = workoutState.slots[i];
                  final sets = workoutState.draftSets[slot.id] ?? [];
                  return _ExerciseLogCard(
                    slot: slot,
                    sets: sets,
                    onAddSet: () => _showSetInput(context, slot, sets.length),
                    onRemoveSet: () => ref
                        .read(activeWorkoutProvider.notifier)
                        .removeLastSet(slot.id),
                    onTapDetail: () =>
                        context.push('/workout/exercise', extra: slot),
                  )
                      .animate()
                      .fadeIn(duration: 300.ms, delay: (60 * i).ms)
                      .slideY(begin: 0.04, end: 0, duration: 300.ms, delay: (60 * i).ms);
                },
              ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(context).padding.bottom + 16,
        ),
        child: ElevatedButton(
          onPressed: workoutState.isSaving
              ? null
              : () {
                  HapticFeedback.heavyImpact();
                  _finish(context);
                },
          child: workoutState.isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Finish Workout'),
        ),
      ),
    );
  }

  Future<void> _finish(BuildContext context) async {
    try {
      await ref.read(activeWorkoutProvider.notifier).finish();
      if (context.mounted) context.go('/');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save workout: $e')),
        );
      }
    }
  }

  void _confirmDiscard(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Discard workout?',
          style: GoogleFonts.outfit(
              color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Your logged sets will not be saved.',
          style:
              GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep going'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Discard',
                style: GoogleFonts.outfit(color: AppColors.danger)),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && context.mounted) {
        ref.read(activeWorkoutProvider.notifier).discard();
        context.go('/');
      }
    });
  }

  void _showSetInput(BuildContext context, ExerciseSlot slot, int setIndex) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SetInputSheet(
        slot: slot,
        setNumber: setIndex + 1,
        onConfirm: (draft) {
          HapticFeedback.mediumImpact();
          ref.read(activeWorkoutProvider.notifier).addSet(slot.id, draft);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }
}

// ── Empty state when no routine exercises ────────────────────────────────────

class _EmptyWorkoutBody extends StatelessWidget {
  const _EmptyWorkoutBody({required this.isSaving});

  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fitness_center,
                color: AppColors.textSecondary, size: 48),
            const SizedBox(height: 20),
            Text(
              'Free workout',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No exercises loaded. Create a routine to track\nspecific exercises day by day.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Exercise log card ────────────────────────────────────────────────────────

class _ExerciseLogCard extends StatelessWidget {
  const _ExerciseLogCard({
    required this.slot,
    required this.sets,
    required this.onAddSet,
    required this.onRemoveSet,
    required this.onTapDetail,
  });

  final ExerciseSlot slot;
  final List<SetDraft> sets;
  final VoidCallback onAddSet;
  final VoidCallback onRemoveSet;
  final VoidCallback onTapDetail;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _typeColor(slot.exerciseType)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _typeIcon(slot.exerciseType),
                    color: _typeColor(slot.exerciseType),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        slot.exerciseName,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        _plannedLabel(slot),
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline,
                      size: 18, color: AppColors.textSecondary),
                  onPressed: onTapDetail,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(),
          // Set rows
          if (sets.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                'No sets logged yet',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            ...sets.asMap().entries.map((e) => _SetRow(
                  setNumber: e.key + 1,
                  draft: e.value,
                  type: slot.exerciseType,
                )),
          // Add / Remove buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: _SmallButton(
                    label: '+ Add set',
                    color: AppColors.accent,
                    onTap: onAddSet,
                  ),
                ),
                if (sets.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _SmallButton(
                    label: 'Remove last',
                    color: AppColors.danger,
                    onTap: onRemoveSet,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _plannedLabel(ExerciseSlot s) {
    final pyramid = s.setType != SetType.straight
        ? ' (${s.setType.label})'
        : '';
    switch (s.exerciseType) {
      case ExerciseType.weights:
        if (s.repsPerSet != null && s.repsPerSet!.isNotEmpty) {
          return 'Planned: ${s.repsPerSet}$pyramid'.trim();
        }
        final reps = s.reps != null ? '${s.reps} reps' : '';
        final weight = s.weightKg != null ? ' @ ${s.weightKg}kg' : '';
        return 'Planned: ${s.sets} × $reps$weight$pyramid'.trim();
      case ExerciseType.bodyweight:
        if (s.repsPerSet != null && s.repsPerSet!.isNotEmpty) {
          return 'Planned: ${s.repsPerSet}$pyramid'.trim();
        }
        final reps = s.reps != null ? '${s.reps} reps' : '';
        return 'Planned: ${s.sets} × $reps$pyramid'.trim();
      case ExerciseType.cardio:
      case ExerciseType.timed:
        final dur =
            s.durationSeconds != null ? '${s.durationSeconds}s' : '';
        return 'Planned: ${s.sets} × $dur'.trim();
    }
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.setNumber,
    required this.draft,
    required this.type,
  });

  final int setNumber;
  final SetDraft draft;
  final ExerciseType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check,
                color: AppColors.success, size: 14),
          ),
          const SizedBox(width: 12),
          Text(
            'Set $setNumber',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _setValueLabel(),
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  String _setValueLabel() {
    switch (type) {
      case ExerciseType.weights:
        final reps = draft.reps != null ? '${draft.reps} reps' : '';
        final weight =
            draft.weightKg != null ? ' × ${draft.weightKg}kg' : '';
        return '$reps$weight';
      case ExerciseType.bodyweight:
        return draft.reps != null ? '${draft.reps} reps' : '';
      case ExerciseType.cardio:
        final dur =
            draft.durationSeconds != null ? '${draft.durationSeconds}s' : '';
        final dist =
            draft.distanceKm != null ? ' · ${draft.distanceKm}km' : '';
        return '$dur$dist';
      case ExerciseType.timed:
        return draft.durationSeconds != null
            ? '${draft.durationSeconds}s'
            : '';
    }
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}

// ── Set input bottom sheet ───────────────────────────────────────────────────

class _SetInputSheet extends ConsumerStatefulWidget {
  const _SetInputSheet({
    required this.slot,
    required this.setNumber,
    required this.onConfirm,
  });

  final ExerciseSlot slot;
  final int setNumber;
  final void Function(SetDraft) onConfirm;

  @override
  ConsumerState<_SetInputSheet> createState() => _SetInputSheetState();
}

class _SetInputSheetState extends ConsumerState<_SetInputSheet> {
  final _repsCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _distanceCtrl = TextEditingController();
  final _hrCtrl = TextEditingController();

  @override
  void dispose() {
    _repsCtrl.dispose();
    _weightCtrl.dispose();
    _durationCtrl.dispose();
    _distanceCtrl.dispose();
    _hrCtrl.dispose();
    super.dispose();
  }

  String? _targetReps() {
    final slot = widget.slot;
    if (slot.repsPerSet != null && slot.repsPerSet!.isNotEmpty) {
      final parts = slot.repsPerSet!.split(',');
      final idx = widget.setNumber - 1;
      if (idx < parts.length) return parts[idx].trim();
    }
    return slot.reps?.toString();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final lastWeights = ref.watch(lastWeightsForExerciseProvider(
      widget.slot.exerciseName,
      widget.slot.sets,
    ));
    final lastWeight = lastWeights.valueOrNull?[widget.setNumber];
    final lastWeightHint = lastWeight != null
        ? '${lastWeight % 1 == 0 ? lastWeight.toInt() : lastWeight}'
        : widget.slot.weightKg?.toString();

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set ${widget.setNumber}  ·  ${widget.slot.exerciseName}',
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          if (lastWeight != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Last: ${lastWeight % 1 == 0 ? lastWeight.toInt() : lastWeight} kg',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: AppColors.accent,
                ),
              ),
            ),
          const SizedBox(height: 20),
          ..._buildFields(lastWeightHint),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _submit,
            child: Text('Log set ${widget.setNumber}'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFields(String? weightHint) {
    final repsHint = _targetReps();
    switch (widget.slot.exerciseType) {
      case ExerciseType.weights:
        return [
          Row(
            children: [
              Expanded(
                child: _NumberField(
                  controller: _repsCtrl,
                  label: 'Reps',
                  hint: repsHint,
                  decimal: false,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NumberField(
                  controller: _weightCtrl,
                  label: 'Weight (kg)',
                  hint: weightHint,
                  decimal: true,
                ),
              ),
            ],
          ),
        ];
      case ExerciseType.bodyweight:
        return [
          _NumberField(
            controller: _repsCtrl,
            label: 'Reps',
            hint: repsHint,
            decimal: false,
          ),
        ];
      case ExerciseType.cardio:
        return [
          Row(
            children: [
              Expanded(
                child: _NumberField(
                  controller: _durationCtrl,
                  label: 'Duration (s)',
                  hint: widget.slot.durationSeconds?.toString(),
                  decimal: false,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NumberField(
                  controller: _distanceCtrl,
                  label: 'Distance (km)',
                  decimal: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _NumberField(
            controller: _hrCtrl,
            label: 'Heart rate (optional)',
            decimal: false,
          ),
        ];
      case ExerciseType.timed:
        return [
          _NumberField(
            controller: _durationCtrl,
            label: 'Duration (s)',
            hint: widget.slot.durationSeconds?.toString(),
            decimal: false,
          ),
        ];
    }
  }

  void _submit() {
    final type = widget.slot.exerciseType;
    widget.onConfirm(SetDraft(
      setNumber: widget.setNumber,
      reps: type == ExerciseType.weights || type == ExerciseType.bodyweight
          ? int.tryParse(_repsCtrl.text)
          : null,
      weightKg: type == ExerciseType.weights
          ? double.tryParse(_weightCtrl.text)
          : null,
      durationSeconds:
          type == ExerciseType.cardio || type == ExerciseType.timed
              ? int.tryParse(_durationCtrl.text)
              : null,
      distanceKm: type == ExerciseType.cardio
          ? double.tryParse(_distanceCtrl.text)
          : null,
      heartRate: type == ExerciseType.cardio
          ? int.tryParse(_hrCtrl.text)
          : null,
    ));
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    this.hint,
    required this.decimal,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType:
          TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [
        if (decimal)
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
        else
          FilteringTextInputFormatter.digitsOnly,
      ],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

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

Color _typeColor(ExerciseType type) {
  switch (type) {
    case ExerciseType.weights:
      return AppColors.accent;
    case ExerciseType.cardio:
      return const Color(0xFF30D158);
    case ExerciseType.timed:
      return const Color(0xFF0A84FF);
    case ExerciseType.bodyweight:
      return const Color(0xFFFF9F0A);
  }
}
