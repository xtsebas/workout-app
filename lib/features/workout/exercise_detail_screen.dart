import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/db/database.dart';
import '../../core/db/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/exercise_type.dart';
import '../../shared/services/wger_service.dart';
import 'workout_provider.dart';

class ExerciseDetailScreen extends ConsumerWidget {
  const ExerciseDetailScreen({super.key, required this.slot});

  final ExerciseSlot slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(slot.exerciseName),
          bottom: TabBar(
            labelStyle: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: GoogleFonts.outfit(fontSize: 14),
            indicatorColor: AppColors.accent,
            labelColor: AppColors.accent,
            unselectedLabelColor: AppColors.textSecondary,
            tabs: const [
              Tab(text: 'Log'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _LogTab(slot: slot),
            _HistoryTab(slot: slot),
          ],
        ),
      ),
    );
  }
}

// ── Log tab ──────────────────────────────────────────────────────────────────

class _LogTab extends ConsumerWidget {
  const _LogTab({required this.slot});

  final ExerciseSlot slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workout = ref.watch(activeWorkoutProvider);
    final sets = workout?.draftSets[slot.id] ?? [];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (slot.wgerExerciseId != null)
          _WgerInfoCard(wgerId: slot.wgerExerciseId!),
        const SizedBox(height: 20),
        _SectionHeader(
          label: 'Current sets',
          trailing: Text(
            '${sets.length} logged',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (sets.isEmpty)
          _EmptyState(
            message: 'No sets logged yet. Go back to add them.',
          )
        else
          ...sets.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _SetSummaryRow(
                  setNumber: e.key + 1,
                  draft: e.value,
                  type: slot.exerciseType,
                ),
              )),
      ],
    );
  }
}

class _WgerInfoCard extends ConsumerWidget {
  const _WgerInfoCard({required this.wgerId});

  final int wgerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoAsync = ref.watch(exerciseInfoProvider(wgerId));

    return infoAsync.when(
      loading: () => Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (info) {
        if (info == null) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (info.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: info.imageUrl!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(
                    height: 180,
                    color: AppColors.surface2,
                    child: const Center(
                        child: CircularProgressIndicator()),
                  ),
                  errorWidget: (_, _, _) =>
                      const SizedBox.shrink(),
                ),
              ),
            if (info.muscleGroup != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  _MuscleChip(label: info.muscleGroup!),
                ],
              ),
            ],
            if (info.description != null &&
                info.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                info.description!,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _MuscleChip extends StatelessWidget {
  const _MuscleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.accent,
        ),
      ),
    );
  }
}

// ── History tab ──────────────────────────────────────────────────────────────

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab({required this.slot});

  final ExerciseSlot slot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(appDatabaseProvider);

    return FutureBuilder<List<SetLogEntry>>(
      future: db.getLastSetsForExercise(slot.exerciseName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final entries = snapshot.data ?? [];
        if (entries.isEmpty) {
          return Center(
            child: _EmptyState(
              message: 'No previous performances found\nfor this exercise.',
            ),
          );
        }

        // Group by workoutLogId
        final grouped = <int, List<SetLogEntry>>{};
        for (final e in entries) {
          grouped.putIfAbsent(e.workoutLogId, () => []).add(e);
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: grouped.length,
          separatorBuilder: (_, _) => const SizedBox(height: 16),
          itemBuilder: (context, i) {
            final logId = grouped.keys.toList()[i];
            final sets = grouped[logId]!;
            return _HistorySessionCard(
              sessionIndex: grouped.length - i,
              sets: sets,
              type: slot.exerciseType,
            );
          },
        );
      },
    );
  }
}

class _HistorySessionCard extends StatelessWidget {
  const _HistorySessionCard({
    required this.sessionIndex,
    required this.sets,
    required this.type,
  });

  final int sessionIndex;
  final List<SetLogEntry> sets;
  final ExerciseType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Session $sessionIndex',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          ...sets.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _HistorySetRow(entry: e, type: type),
              )),
        ],
      ),
    );
  }
}

class _HistorySetRow extends StatelessWidget {
  const _HistorySetRow({required this.entry, required this.type});

  final SetLogEntry entry;
  final ExerciseType type;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Set ${entry.setNumber}',
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _label(),
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  String _label() {
    switch (type) {
      case ExerciseType.weights:
        final reps = entry.reps != null ? '${entry.reps} reps' : '';
        final weight =
            entry.weightKg != null ? ' × ${entry.weightKg}kg' : '';
        return '$reps$weight';
      case ExerciseType.bodyweight:
        return entry.reps != null ? '${entry.reps} reps' : '';
      case ExerciseType.cardio:
        final dur = entry.durationSeconds != null
            ? '${entry.durationSeconds}s'
            : '';
        final dist =
            entry.distanceKm != null ? ' · ${entry.distanceKm}km' : '';
        return '$dur$dist';
      case ExerciseType.timed:
        return entry.durationSeconds != null
            ? '${entry.durationSeconds}s'
            : '';
    }
  }
}

// ── Shared widgets ───────────────────────────────────────────────────────────

class _SetSummaryRow extends StatelessWidget {
  const _SetSummaryRow({
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check,
                color: AppColors.success, size: 13),
          ),
          const SizedBox(width: 12),
          Text(
            'Set $setNumber',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _valueLabel(),
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

  String _valueLabel() {
    switch (type) {
      case ExerciseType.weights:
        final reps = draft.reps != null ? '${draft.reps} reps' : '';
        final w =
            draft.weightKg != null ? ' × ${draft.weightKg}kg' : '';
        return '$reps$w';
      case ExerciseType.bodyweight:
        return draft.reps != null ? '${draft.reps} reps' : '';
      case ExerciseType.cardio:
        final dur = draft.durationSeconds != null
            ? '${draft.durationSeconds}s'
            : '';
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
