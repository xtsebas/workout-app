import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:printing/printing.dart';

import '../../core/db/database.dart';
import '../../core/db/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/services/progress_pdf_service.dart';
import '../../shared/widgets/skeleton_loader.dart';
import 'progress_provider.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen>
    with SingleTickerProviderStateMixin {
  late DateTime _selectedMonth;
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _downloadPdf(BuildContext context, WidgetRef ref, String mode) async {
    final db = ref.read(appDatabaseProvider);
    final names = await db.getDistinctExerciseNames();
    if (names.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No workout data to export')),
        );
      }
      return;
    }

    String title;
    String dateRange;
    List<WorkoutLog> logs;

    if (mode == 'current') {
      logs = await db.getLogsForMonth(_selectedMonth.year, _selectedMonth.month);
      title = 'Progress Report';
      dateRange = DateFormat('MMMM y').format(_selectedMonth);
    } else {
      logs = await (db.select(db.workoutLogs)
            ..where((t) => t.isCompleted.equals(true))
            ..orderBy([(t) => OrderingTerm.desc(t.date)]))
          .get();
      title = 'Progress Report';
      dateRange = logs.isNotEmpty
          ? '${DateFormat('MMM d, y').format(logs.last.date)} — ${DateFormat('MMM d, y').format(logs.first.date)}'
          : 'All time';
    }

    final exercises = <ExerciseReport>[];
    for (final name in names) {
      final history = await db.getExerciseHistory(name);
      if (history.isEmpty) continue;
      exercises.add(ExerciseReport(
        name: name,
        sessions: history.length,
        firstWeight: history.first.maxWeight,
        lastWeight: history.last.maxWeight,
        bestWeight: history.fold(0.0, (m, h) => h.maxWeight > m ? h.maxWeight : m),
        bestReps: history.fold(0, (m, h) => h.bestReps > m ? h.bestReps : m),
        totalVolume: history.fold(0.0, (s, h) => s + h.totalVolume),
        history: history,
      ));
    }

    final streak = await db.currentStreak();

    const service = ProgressPdfService();
    final bytes = await service.generate(
      title: title,
      dateRange: dateRange,
      logs: logs,
      exercises: exercises,
      streak: streak,
    );

    await Printing.sharePdf(bytes: bytes, filename: 'workout_progress.pdf');
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.download, color: AppColors.textSecondary, size: 22),
            color: AppColors.surface2,
            onSelected: (value) => _downloadPdf(context, ref, value),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'current',
                child: Text(
                  'Download ${DateFormat('MMMM y').format(_selectedMonth)}',
                  style: GoogleFonts.outfit(color: AppColors.textPrimary),
                ),
              ),
              PopupMenuItem(
                value: 'all',
                child: Text('Download all time',
                    style: GoogleFonts.outfit(color: AppColors.textPrimary)),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500),
          tabs: const [
            Tab(text: 'Calendar'),
            Tab(text: 'Exercises'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _CalendarTab(
            selectedMonth: _selectedMonth,
            onChangeMonth: _changeMonth,
          ),
          const _ExercisesTab(),
        ],
      ),
    );
  }

}

// ── Calendar tab ─────────────────────────────────────────────────────────────

class _CalendarTab extends ConsumerWidget {
  const _CalendarTab({required this.selectedMonth, required this.onChangeMonth});

  final DateTime selectedMonth;
  final void Function(int delta) onChangeMonth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(
      monthStatsProvider(selectedMonth.year, selectedMonth.month),
    );

    return statsAsync.when(
      loading: () => const ProgressSkeleton(),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (stats) => RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.surface,
        onRefresh: () async =>
            ref.invalidate(monthStatsProvider(selectedMonth.year, selectedMonth.month)),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _StatsStrip(stats: stats),
            const SizedBox(height: 24),
            _MonthSelector(
              month: selectedMonth,
              onPrevious: () => onChangeMonth(-1),
              onNext: () => onChangeMonth(1),
            ),
            const SizedBox(height: 16),
            _Calendar(
              month: selectedMonth,
              workoutDates: stats.workoutDates,
              onDayTap: (day) => _showDayDetail(context, ref, stats.logs, day),
            ),
            const SizedBox(height: 28),
            _WorkoutHistory(logs: stats.logs),
          ],
        ),
      ),
    );
  }

  void _showDayDetail(
      BuildContext context, WidgetRef ref, List<WorkoutLog> logs, int day) {
    final dayLogs = logs.where((l) => l.date.day == day).toList();
    if (dayLogs.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DayDetailSheet(log: dayLogs.first),
    );
  }
}

// ── Exercises tab ────────────────────────────────────────────────────────────

class _ExercisesTab extends ConsumerWidget {
  const _ExercisesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final namesAsync = ref.watch(exerciseNamesProvider);

    return namesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (names) {
        if (names.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.show_chart,
                      color: AppColors.textSecondary, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'No exercise data yet',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Complete workouts to see your\nprogress charts here.',
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

        return RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.surface,
          onRefresh: () async => ref.invalidate(exerciseNamesProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: names.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) => GestureDetector(
              onTap: () => context.push('/progress/exercise', extra: names[i]),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder, width: 0.5),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.show_chart,
                          color: AppColors.accent, size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        names[i],
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: AppColors.textSecondary, size: 18),
                  ],
                ),
              ),
            )
                .animate()
                .fadeIn(duration: 300.ms, delay: (40 * i).ms)
                .slideX(begin: -0.02, end: 0, duration: 300.ms, delay: (40 * i).ms),
          ),
        );
      },
    );
  }
}

// ── Stats strip ──────────────────────────────────────────────────────────────

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.stats});

  final MonthStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(
          label: 'Streak',
          value: '${stats.streak}',
          unit: 'days',
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: 'Sessions',
          value: '${stats.totalSessions}',
          unit: 'this month',
        ),
        const SizedBox(width: 10),
        _StatCard(
          label: 'Volume',
          value: _formatVolume(stats.totalVolumeKg),
          unit: 'kg',
        ),
      ],
    );
  }

  String _formatVolume(double kg) {
    if (kg >= 1000) return '${(kg / 1000).toStringAsFixed(1)}k';
    return kg.toStringAsFixed(0);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              unit,
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Month selector ───────────────────────────────────────────────────────────

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentMonth = month.year == now.year && month.month == now.month;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left,
              color: AppColors.textSecondary, size: 22),
          onPressed: onPrevious,
        ),
        Text(
          DateFormat.yMMMM().format(month),
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        IconButton(
          icon: Icon(Icons.chevron_right,
              color: isCurrentMonth
                  ? AppColors.surface2
                  : AppColors.textSecondary,
              size: 22),
          onPressed: isCurrentMonth ? null : onNext,
        ),
      ],
    );
  }
}

// ── Calendar ─────────────────────────────────────────────────────────────────

class _Calendar extends StatelessWidget {
  const _Calendar({
    required this.month,
    required this.workoutDates,
    required this.onDayTap,
  });

  final DateTime month;
  final Set<int> workoutDates;
  final void Function(int day) onDayTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final startWeekday = firstDay.weekday; // 1=Mon

    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Column(
      children: [
        Row(
          children: dayLabels
              .map((d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        ...List.generate(_totalRows(daysInMonth, startWeekday), (row) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: List.generate(7, (col) {
                final dayNum = row * 7 + col - (startWeekday - 1) + 1;
                if (dayNum < 1 || dayNum > daysInMonth) {
                  return const Expanded(child: SizedBox(height: 40));
                }

                final isToday = month.year == now.year &&
                    month.month == now.month &&
                    dayNum == now.day;
                final hasWorkout = workoutDates.contains(dayNum);

                return Expanded(
                  child: GestureDetector(
                    onTap: hasWorkout
                        ? () {
                            HapticFeedback.lightImpact();
                            onDayTap(dayNum);
                          }
                        : null,
                    child: Container(
                      height: 40,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: hasWorkout
                            ? AppColors.accent.withValues(alpha: 0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isToday
                            ? Border.all(color: AppColors.accent, width: 1.5)
                            : null,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$dayNum',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight:
                                    isToday ? FontWeight.w700 : FontWeight.w400,
                                color: isToday
                                    ? AppColors.accent
                                    : AppColors.textPrimary,
                              ),
                            ),
                            if (hasWorkout)
                              Container(
                                width: 5,
                                height: 5,
                                margin: const EdgeInsets.only(top: 2),
                                decoration: const BoxDecoration(
                                  color: AppColors.accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ],
    );
  }

  int _totalRows(int daysInMonth, int startWeekday) =>
      ((daysInMonth + startWeekday - 1) / 7).ceil();
}

// ── Workout history ──────────────────────────────────────────────────────────

class _WorkoutHistory extends StatelessWidget {
  const _WorkoutHistory({required this.logs});

  final List<WorkoutLog> logs;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Center(
          child: Text(
            'No workouts this month',
            style: GoogleFonts.outfit(
                fontSize: 14, color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HISTORY',
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        ...logs.asMap().entries.map((e) => _LogTile(log: e.value)
            .animate()
            .fadeIn(duration: 300.ms, delay: (50 * e.key).ms)
            .slideY(begin: 0.05, end: 0, duration: 300.ms, delay: (50 * e.key).ms)),
      ],
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.log});

  final WorkoutLog log;

  @override
  Widget build(BuildContext context) {
    final dayLabel = _weekdayShort(log.weekday);
    final dateStr = DateFormat('MMM d').format(log.date);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.fitness_center,
                color: AppColors.accent, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$dayLabel — $dateStr',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${log.durationMinutes} min',
                  style: GoogleFonts.outfit(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right,
              color: AppColors.textSecondary, size: 18),
        ],
      ),
    );
  }

  String _weekdayShort(int wd) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[(wd - 1).clamp(0, 6)];
  }
}

// ── Day detail bottom sheet ──────────────────────────────────────────────────

class _DayDetailSheet extends ConsumerWidget {
  const _DayDetailSheet({required this.log});

  final WorkoutLog log;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(logEntriesProvider(log.id));
    final dateStr = DateFormat('EEEE, MMM d').format(log.date);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateStr,
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${log.durationMinutes} min',
            style: GoogleFonts.outfit(
                fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          entriesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
            data: (entries) {
              if (entries.isEmpty) {
                return Text(
                  'No set data recorded',
                  style: GoogleFonts.outfit(
                      fontSize: 13, color: AppColors.textSecondary),
                );
              }

              final grouped = <String, List<SetLogEntry>>{};
              for (final e in entries) {
                grouped.putIfAbsent(e.exerciseName, () => []).add(e);
              }

              return Column(
                children: grouped.entries.map((entry) {
                  final sets = entry.value;
                  final summary = _buildSummary(sets);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          summary,
                          style: GoogleFonts.outfit(
                              fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  String _buildSummary(List<SetLogEntry> sets) {
    final count = sets.length;
    final reps = sets.where((s) => s.reps != null).map((s) => s.reps!);
    if (reps.isEmpty) return '$count sets';
    final maxWeight = sets
        .where((s) => s.weightKg != null)
        .map((s) => s.weightKg!)
        .fold<double>(0, (a, b) => a > b ? a : b);
    if (maxWeight > 0) {
      return '$count × ${reps.first} @ ${maxWeight % 1 == 0 ? maxWeight.toInt() : maxWeight} kg';
    }
    return '$count × ${reps.first}';
  }
}
