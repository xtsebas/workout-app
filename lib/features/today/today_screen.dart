import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/db/database.dart';
import '../../core/db/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/exercise_type.dart';
import '../../shared/utils/weight_converter.dart' as wc;
import '../../shared/widgets/skeleton_loader.dart';
import '../workout/workout_provider.dart';
import 'today_provider.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(todayDataProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.surface,
          onRefresh: () async => ref.invalidate(todayDataProvider),
          child: dataAsync.when(
            loading: () => const TodaySkeleton(),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (data) => _TodayContent(data: data),
          ),
        ),
      ),
    );
  }
}

class _TodayContent extends ConsumerWidget {
  const _TodayContent({required this.data});

  final TodayData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(weightUnitProvider).valueOrNull ?? 'kg';
    final today = data.today;
    final weekdayName = _weekdayName(data.selectedWeekday);
    final isOverride = data.selectedWeekday != today.weekday;
    final monthDay =
        '${_monthName(today.month)} ${today.day}';

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            weekdayName,
                            style: GoogleFonts.outfit(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isOverride
                                ? '$monthDay — swapped day'
                                : monthDay,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: isOverride
                                  ? AppColors.accent
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isOverride)
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: AppColors.textSecondary, size: 20),
                        onPressed: () => ref
                            .read(weekdayOverrideProvider.notifier)
                            .set(null),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _WeekdaySelector(
                  selectedWeekday: data.selectedWeekday,
                  onSelect: (wd) => ref
                      .read(weekdayOverrideProvider.notifier)
                      .set(wd == today.weekday ? null : wd),
                ),
                const SizedBox(height: 20),
                _StatsRow(data: data),
                const SizedBox(height: 16),
                _IncompleteWorkoutBanner(
                  onContinue: (log) => _continueWorkout(context, ref, log),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: _buildBody(context, ref, unit),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, String unit) {
    if (data.routine == null) {
      return SliverToBoxAdapter(child: _NoRoutineCard());
    }

    if (data.routineDay == null) {
      return SliverToBoxAdapter(
        child: _RestDayCard(
          onFreeWorkout: () => _launchFreeWorkout(context, ref),
        ),
      );
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    data.routine!.name,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.accent,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: AppColors.textSecondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    data.routineDay!.label,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        if (data.slots.isEmpty)
          SliverToBoxAdapter(
            child: _EmptyDayCard(),
          )
        else
          SliverList.separated(
            itemCount: data.slots.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _ExerciseCard(slot: data.slots[i], unit: unit)
                .animate()
                .fadeIn(duration: 300.ms, delay: (50 * i).ms)
                .slideX(begin: -0.02, end: 0, duration: 300.ms, delay: (50 * i).ms),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 24),
            child: ElevatedButton(
              onPressed: data.slots.isEmpty
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      _launchWorkout(context, ref);
                    },
              child: const Text('Start Workout'),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _launchWorkout(BuildContext context, WidgetRef ref) async {
    await ref.read(activeWorkoutProvider.notifier).start(
          slots: data.slots,
          routineId: data.routine?.id,
        );
    if (context.mounted) context.push('/workout/active');
  }

  Future<void> _launchFreeWorkout(BuildContext context, WidgetRef ref) async {
    await ref.read(activeWorkoutProvider.notifier).start(
          slots: [],
          routineId: null,
        );
    if (context.mounted) context.push('/workout/active');
  }

  Future<void> _continueWorkout(BuildContext context, WidgetRef ref, WorkoutLog log) async {
    final db = ref.read(appDatabaseProvider);
    List<ExerciseSlot> slots = [];
    if (log.routineId != null) {
      final day = await db.getDayForWeekday(log.routineId!, log.weekday);
      if (day != null) slots = await db.getSlotsForDay(day.id);
    }
    await ref.read(activeWorkoutProvider.notifier).restore(log, slots);
    if (context.mounted) context.push('/workout/active');
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.data});

  final TodayData data;

  @override
  Widget build(BuildContext context) {
    final lastWorkoutText = data.lastLog == null
        ? 'No workouts yet'
        : 'Last: ${_relativeDays(data.lastLog!.date)}';

    return Row(
      children: [
        _StatChip(
          label: '${data.logsThisWeek}',
          subtitle: 'this week',
        ),
        const SizedBox(width: 12),
        _StatChip(
          label: lastWorkoutText,
          subtitle: '',
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.subtitle});

  final String label;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: subtitle.isEmpty
          ? Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({required this.slot, required this.unit});

  final ExerciseSlot slot;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _typeColor(slot.exerciseType).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _typeIcon(slot.exerciseType),
              color: _typeColor(slot.exerciseType),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
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
                const SizedBox(height: 3),
                Text(
                  _slotSummary(slot),
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _slotSummary(ExerciseSlot s) {
    switch (s.exerciseType) {
      case ExerciseType.weights:
        final reps = s.reps != null ? '× ${s.reps} reps' : '';
        final weight = s.weightKg != null ? ' @ ${wc.fmtWeight(s.weightKg, unit)}$unit' : '';
        return '${s.sets} sets $reps$weight'.trim();
      case ExerciseType.bodyweight:
        final reps = s.reps != null ? '× ${s.reps} reps' : '';
        return '${s.sets} sets $reps'.trim();
      case ExerciseType.cardio:
      case ExerciseType.timed:
        final dur = s.durationSeconds != null
            ? '× ${s.durationSeconds}s'
            : '';
        return '${s.sets} sets $dur'.trim();
    }
  }
}

class _NoRoutineCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.calendar_today_outlined,
              color: AppColors.textSecondary, size: 28),
          const SizedBox(height: 16),
          Text(
            'No active routine',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a routine to track your workouts day by day.',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => context.push('/routines'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text('Manage routines'),
          ),
        ],
      ),
    );
  }
}

class _RestDayCard extends StatelessWidget {
  const _RestDayCard({required this.onFreeWorkout});

  final VoidCallback onFreeWorkout;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.self_improvement,
              color: AppColors.textSecondary, size: 28),
          const SizedBox(height: 16),
          Text(
            'Rest day',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your routine has no exercises scheduled today.',
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: onFreeWorkout,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text('Log free workout'),
          ),
        ],
      ),
    );
  }
}

class _EmptyDayCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: Text(
        'No exercises added for today.',
        style: GoogleFonts.outfit(
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _IncompleteWorkoutBanner extends ConsumerWidget {
  const _IncompleteWorkoutBanner({required this.onContinue});

  final void Function(WorkoutLog log) onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incompleteAsync = ref.watch(incompleteWorkoutProvider);
    final log = incompleteAsync.valueOrNull;
    if (log == null) return const SizedBox.shrink();

    final elapsed = DateTime.now().difference(log.date);
    final label = elapsed.inMinutes < 60
        ? '${elapsed.inMinutes} min ago'
        : '${elapsed.inHours}h ago';

    return GestureDetector(
      onTap: () => onContinue(log),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accent, width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.play_circle_fill,
                color: AppColors.accent, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Workout in progress',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Started $label',
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Text(
              'Continue',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekdaySelector extends StatelessWidget {
  const _WeekdaySelector({required this.selectedWeekday, required this.onSelect});

  final int selectedWeekday;
  final void Function(int) onSelect;

  static const _labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final todayWd = DateTime.now().weekday;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final wd = i + 1;
        final isSelected = wd == selectedWeekday;
        final isToday = wd == todayWd;
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            onSelect(wd);
          },
          child: Container(
            width: 42,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? AppColors.accent
                    : isToday
                        ? AppColors.accent.withValues(alpha: 0.4)
                        : AppColors.cardBorder,
                width: isSelected ? 1.5 : 0.5,
              ),
            ),
            child: Center(
              child: Text(
                _labels[i],
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.onAccent
                      : isToday
                          ? AppColors.accent
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

String _weekdayName(int weekday) {
  const names = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return names[(weekday - 1).clamp(0, 6)];
}

String _monthName(int month) {
  const names = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return names[(month - 1).clamp(0, 11)];
}

String _relativeDays(DateTime date) {
  final diff = DateTime.now().difference(date).inDays;
  if (diff == 0) return 'today';
  if (diff == 1) return 'yesterday';
  return '$diff days ago';
}
