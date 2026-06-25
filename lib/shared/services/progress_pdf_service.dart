import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/db/database.dart';

class ExerciseReport {
  const ExerciseReport({
    required this.name,
    required this.sessions,
    required this.firstWeight,
    required this.lastWeight,
    required this.bestWeight,
    required this.bestReps,
    required this.totalVolume,
    required this.history,
  });

  final String name;
  final int sessions;
  final double firstWeight;
  final double lastWeight;
  final double bestWeight;
  final int bestReps;
  final double totalVolume;
  final List<({DateTime date, double maxWeight, int bestReps, double totalVolume})> history;

  double get progression => lastWeight - firstWeight;
}

class ProgressPdfService {
  const ProgressPdfService();

  Future<Uint8List> generate({
    required String title,
    required String dateRange,
    required List<WorkoutLog> logs,
    required List<ExerciseReport> exercises,
    required int streak,
  }) async {
    final pdf = pw.Document();
    final accent = PdfColor.fromHex('#BF5AF2');
    final headerStyle = pw.TextStyle(
        fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.white);
    final subStyle = pw.TextStyle(fontSize: 12, color: PdfColors.grey400);
    final sectionStyle = pw.TextStyle(
        fontSize: 14, fontWeight: pw.FontWeight.bold, color: accent);
    final bodyStyle = const pw.TextStyle(fontSize: 10, color: PdfColors.white);
    final smallStyle = pw.TextStyle(fontSize: 9, color: PdfColors.grey500);
    final surface = PdfColor.fromHex('#1C1C1E');

    final totalSessions = logs.length;
    final totalVolume = exercises.fold<double>(0, (s, e) => s + e.totalVolume);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(),
        build: (context) => [
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              color: surface,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(title, style: headerStyle),
                pw.SizedBox(height: 4),
                pw.Text(dateRange, style: subStyle),
                pw.SizedBox(height: 16),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _statBox('Sessions', '$totalSessions', surface),
                    _statBox('Streak', '$streak days', surface),
                    _statBox('Volume', _fmtVolume(totalVolume), surface),
                    _statBox('Exercises', '${exercises.length}', surface),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 24),

          // Per-exercise sections
          ...exercises.map((ex) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 20),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: double.infinity,
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: pw.BoxDecoration(
                        color: surface,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Row(
                        mainAxisAlignment:
                            pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(ex.name, style: sectionStyle),
                          pw.Text(
                            '${ex.sessions} sessions',
                            style: smallStyle,
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 8),

                    // Progress summary
                    pw.Row(
                      children: [
                        _miniStat('Start', '${_fmtW(ex.firstWeight)} kg'),
                        _miniStat('Current', '${_fmtW(ex.lastWeight)} kg'),
                        _miniStat(
                          'Change',
                          '${ex.progression >= 0 ? '+' : ''}${_fmtW(ex.progression)} kg',
                        ),
                        _miniStat('Best', '${_fmtW(ex.bestWeight)} kg'),
                        _miniStat('Max reps', '${ex.bestReps}'),
                      ],
                    ),
                    pw.SizedBox(height: 8),

                    // History table
                    pw.TableHelper.fromTextArray(
                      headerStyle: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white),
                      cellStyle: bodyStyle,
                      headerDecoration:
                          pw.BoxDecoration(color: surface),
                      cellHeight: 22,
                      headerHeight: 26,
                      cellAlignments: {
                        0: pw.Alignment.centerLeft,
                        1: pw.Alignment.center,
                        2: pw.Alignment.center,
                        3: pw.Alignment.center,
                      },
                      headers: ['Date', 'Max Weight', 'Best Reps', 'Volume'],
                      data: ex.history
                          .map((h) => [
                                DateFormat('MMM d, y').format(h.date),
                                '${_fmtW(h.maxWeight)} kg',
                                '${h.bestReps}',
                                '${_fmtW(h.totalVolume)} kg',
                              ])
                          .toList(),
                    ),
                  ],
                ),
              )),
        ],
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Generated ${DateFormat('MMM d, y').format(DateTime.now())} — Workout App',
            style: smallStyle,
          ),
        ),
      ),
    );

    return pdf.save();
  }

  pw.Widget _statBox(String label, String value, PdfColor bg) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: pw.Column(
        children: [
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white)),
          pw.SizedBox(height: 2),
          pw.Text(label,
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
        ],
      ),
    );
  }

  pw.Widget _miniStat(String label, String value) {
    return pw.Expanded(
      child: pw.Column(
        children: [
          pw.Text(value,
              style:
                  pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          pw.Text(label,
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
        ],
      ),
    );
  }

  String _fmtW(double w) => w % 1 == 0 ? '${w.toInt()}' : w.toStringAsFixed(1);

  String _fmtVolume(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k kg';
    return '${v.toStringAsFixed(0)} kg';
  }
}
