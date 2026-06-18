import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import 'progress_provider.dart';

class ExerciseProgressScreen extends ConsumerWidget {
  const ExerciseProgressScreen({super.key, required this.exerciseName});

  final String exerciseName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(exerciseHistoryProvider(exerciseName));

    return Scaffold(
      appBar: AppBar(title: Text(exerciseName)),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          if (data.isEmpty) {
            return Center(
              child: Text(
                'No data yet for this exercise',
                style: GoogleFonts.outfit(
                    fontSize: 14, color: AppColors.textSecondary),
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.accent,
            backgroundColor: AppColors.surface,
            onRefresh: () async =>
                ref.invalidate(exerciseHistoryProvider(exerciseName)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              children: [
                _SummaryRow(data: data),
                const SizedBox(height: 28),
                _ChartSection(
                  title: 'Max Weight (kg)',
                  data: data,
                  getValue: (d) => d.maxWeight,
                  color: AppColors.accent,
                  unit: 'kg',
                ),
                const SizedBox(height: 28),
                _ChartSection(
                  title: 'Best Reps',
                  data: data,
                  getValue: (d) => d.bestReps.toDouble(),
                  color: const Color(0xFF32D74B),
                  unit: 'reps',
                ),
                const SizedBox(height: 28),
                _ChartSection(
                  title: 'Volume (kg)',
                  data: data,
                  getValue: (d) => d.totalVolume,
                  color: const Color(0xFF0A84FF),
                  unit: 'kg',
                ),
                const SizedBox(height: 28),
                _HistoryTable(data: data),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Summary row ──────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.data});

  final List<({DateTime date, double maxWeight, int bestReps, double totalVolume})> data;

  @override
  Widget build(BuildContext context) {
    final allTimeMax = data.fold<double>(0, (m, d) => d.maxWeight > m ? d.maxWeight : m);
    final allTimeBestReps = data.fold<int>(0, (m, d) => d.bestReps > m ? d.bestReps : m);
    final sessions = data.length;

    return Row(
      children: [
        _MiniStat(label: 'Best', value: '${allTimeMax % 1 == 0 ? allTimeMax.toInt() : allTimeMax}', unit: 'kg'),
        const SizedBox(width: 10),
        _MiniStat(label: 'Max reps', value: '$allTimeBestReps', unit: ''),
        const SizedBox(width: 10),
        _MiniStat(label: 'Sessions', value: '$sessions', unit: ''),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, required this.unit});

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
            Text(label,
                style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value,
                    style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 3),
                  Text(unit, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chart section ────────────────────────────────────────────────────────────

class _ChartSection extends StatelessWidget {
  const _ChartSection({
    required this.title,
    required this.data,
    required this.getValue,
    required this.color,
    required this.unit,
  });

  final String title;
  final List<({DateTime date, double maxWeight, int bestReps, double totalVolume})> data;
  final double Function(({DateTime date, double maxWeight, int bestReps, double totalVolume})) getValue;
  final Color color;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final values = data.map(getValue).toList();
    final allZero = values.every((v) => v == 0);
    if (allZero) return const SizedBox.shrink();

    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.15;
    final chartMin = (minY - padding).clamp(0.0, double.infinity);
    final chartMax = maxY + padding;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 180,
          padding: const EdgeInsets.fromLTRB(0, 12, 16, 0),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.cardBorder, width: 0.5),
          ),
          child: LineChart(
            LineChartData(
              minY: chartMin,
              maxY: chartMax,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: _interval(chartMin, chartMax),
                getDrawingHorizontalLine: (_) => FlLine(
                  color: AppColors.cardBorder,
                  strokeWidth: 0.5,
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: _xInterval(data.length),
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= data.length) return const SizedBox.shrink();
                      return Text(
                        DateFormat('d/M').format(data[i].date),
                        style: GoogleFonts.outfit(fontSize: 9, color: AppColors.textSecondary),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: _interval(chartMin, chartMax),
                    getTitlesWidget: (value, meta) => Text(
                      value % 1 == 0 ? '${value.toInt()}' : value.toStringAsFixed(1),
                      style: GoogleFonts.outfit(fontSize: 10, color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(data.length, (i) => FlSpot(i.toDouble(), getValue(data[i]))),
                  isCurved: true,
                  curveSmoothness: 0.25,
                  color: color,
                  barWidth: 2.5,
                  dotData: FlDotData(
                    show: data.length <= 15,
                    getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                      radius: 3,
                      color: color,
                      strokeWidth: 0,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: color.withValues(alpha: 0.08),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => AppColors.surface2,
                  tooltipRoundedRadius: 8,
                  getTooltipItems: (spots) => spots.map((s) {
                    final i = s.x.toInt();
                    final dateStr = i >= 0 && i < data.length
                        ? DateFormat('MMM d').format(data[i].date)
                        : '';
                    return LineTooltipItem(
                      '$dateStr\n${s.y % 1 == 0 ? s.y.toInt() : s.y.toStringAsFixed(1)} $unit',
                      GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _interval(double min, double max) {
    final range = max - min;
    if (range <= 5) return 1;
    if (range <= 20) return 5;
    if (range <= 50) return 10;
    if (range <= 200) return 25;
    return 50;
  }

  double _xInterval(int count) {
    if (count <= 7) return 1;
    if (count <= 15) return 2;
    if (count <= 30) return 5;
    return (count / 6).ceilToDouble();
  }
}

// ── History table ────────────────────────────────────────────────────────────

class _HistoryTable extends StatelessWidget {
  const _HistoryTable({required this.data});

  final List<({DateTime date, double maxWeight, int bestReps, double totalVolume})> data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ALL SESSIONS',
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder, width: 0.5),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    _headerCell('Date', flex: 3),
                    _headerCell('Weight', flex: 2),
                    _headerCell('Reps', flex: 2),
                    _headerCell('Volume', flex: 2),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 0.5, color: AppColors.cardBorder),
              // Rows (newest first)
              ...data.reversed.map((d) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        _dataCell(DateFormat('MMM d').format(d.date), flex: 3),
                        _dataCell('${d.maxWeight % 1 == 0 ? d.maxWeight.toInt() : d.maxWeight} kg', flex: 2),
                        _dataCell('${d.bestReps}', flex: 2),
                        _dataCell('${d.totalVolume % 1 == 0 ? d.totalVolume.toInt() : d.totalVolume.toStringAsFixed(1)}', flex: 2),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _headerCell(String text, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _dataCell(String text, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textPrimary),
      ),
    );
  }
}
