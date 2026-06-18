import 'package:drift/drift.dart' hide Column;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/db/database.dart';
import '../../core/db/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/services/groq_parser_service.dart';
import '../../shared/services/pdf_service.dart';

enum _Step { idle, loading, review, saving, error }

class PdfImportScreen extends ConsumerStatefulWidget {
  const PdfImportScreen({super.key});

  @override
  ConsumerState<PdfImportScreen> createState() => _PdfImportScreenState();
}

class _PdfImportScreenState extends ConsumerState<PdfImportScreen> {
  _Step _step = _Step.idle;
  String _errorMessage = '';

  final _nameCtrl = TextEditingController(text: 'Imported Routine');
  late List<ParsedDay> _days;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndParse() async {
    setState(() => _step = _Step.loading);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.single.path == null) {
        setState(() => _step = _Step.idle);
        return;
      }

      final path = result.files.single.path!;
      final name = result.files.single.name
          .replaceAll('.pdf', '')
          .replaceAll('_', ' ')
          .replaceAll('-', ' ')
          .trim();

      final text = await const PdfService().extractText(path);
      final fallback = name.isNotEmpty ? name : 'Imported Routine';
      final parsed = await GroqParserService().parse(text, fallbackName: fallback);

      _nameCtrl.text = parsed.name;
      _days = List<ParsedDay>.from(parsed.days);

      if (_days.isEmpty) {
        setState(() {
          _step = _Step.error;
          _errorMessage = 'No exercises found in this PDF.\n\nTry a PDF with a clearer structure (e.g. day headings and exercise names with sets and reps).';
        });
        return;
      }

      setState(() => _step = _Step.review);
    } catch (e) {
      setState(() {
        _step = _Step.error;
        _errorMessage = e.toString();
      });
    }
  }

  void _removeExercise(int dayIndex, int exIndex) {
    setState(() {
      _days[dayIndex].exercises.removeAt(exIndex);
      if (_days[dayIndex].exercises.isEmpty) _days.removeAt(dayIndex);
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _days.isEmpty) return;

    setState(() => _step = _Step.saving);

    try {
      final db = ref.read(appDatabaseProvider);
      await db.transaction(() async {
        final routineId = await db.insertRoutine(
          RoutinesCompanion(name: Value(name)),
        );
        for (final day in _days) {
          final dayId = await db.insertRoutineDay(RoutineDaysCompanion(
            routineId: Value(routineId),
            weekday: Value(day.weekday),
            label: Value(day.label),
          ));
          for (var i = 0; i < day.exercises.length; i++) {
            final ex = day.exercises[i];
            await db.insertExerciseSlot(ExerciseSlotsCompanion(
              routineDayId: Value(dayId),
              sortOrder: Value(i),
              exerciseName: Value(ex.name),
              exerciseType: Value(ex.type),
              sets: Value(ex.sets),
              reps: Value(ex.reps),
              durationSeconds: Value(ex.durationSeconds),
              weightKg: Value(ex.weightKg),
              wgerExerciseId: const Value(null),
            ));
          }
        }
      });

      if (mounted) context.pop();
    } catch (e) {
      setState(() {
        _step = _Step.error;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import from PDF')),
      body: switch (_step) {
        _Step.idle => _IdleView(onPick: _pickAndParse),
        _Step.loading => const _LoadingView(),
        _Step.saving => const _LoadingView(message: 'Saving routine…'),
        _Step.error => _ErrorView(
            message: _errorMessage,
            onRetry: () => setState(() => _step = _Step.idle),
          ),
        _Step.review => _ReviewView(
            nameCtrl: _nameCtrl,
            days: _days,
            onRemoveExercise: _removeExercise,
            onSave: _save,
          ),
      },
    );
  }
}

// ── Idle ──────────────────────────────────────────────────────────────────────

class _IdleView extends StatelessWidget {
  const _IdleView({required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.cardBorder, width: 0.5),
              ),
              child: const Icon(Icons.picture_as_pdf_outlined,
                  color: AppColors.accent, size: 36),
            ),
            const SizedBox(height: 24),
            Text(
              'Import a workout PDF',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Select a PDF with your routine.\nExercises like "Squat 4x10 @ 80kg" or\n"Press Banca 4 series x 10 reps" are detected automatically.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.upload_file, size: 18),
              label: const Text('Choose PDF'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Loading ───────────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView({this.message = 'Reading PDF…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.outfit(
                fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Error ─────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
            const SizedBox(height: 20),
            Text(
              'Could not parse PDF',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                  fontSize: 13, color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 28),
            ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

// ── Review ────────────────────────────────────────────────────────────────────

class _ReviewView extends StatelessWidget {
  const _ReviewView({
    required this.nameCtrl,
    required this.days,
    required this.onRemoveExercise,
    required this.onSave,
  });

  final TextEditingController nameCtrl;
  final List<ParsedDay> days;
  final void Function(int dayIndex, int exIndex) onRemoveExercise;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Review imported routine',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
                decoration: const InputDecoration(labelText: 'Routine name'),
              ),
              const SizedBox(height: 24),
              ...List.generate(days.length, (di) => _DayReview(
                    day: days[di],
                    dayIndex: di,
                    onRemoveExercise: onRemoveExercise,
                  )),
            ],
          ),
        ),
        _SaveBar(
          totalExercises: days.fold(0, (s, d) => s + d.exercises.length),
          onSave: onSave,
        ),
      ],
    );
  }
}

class _DayReview extends StatelessWidget {
  const _DayReview({
    required this.day,
    required this.dayIndex,
    required this.onRemoveExercise,
  });

  final ParsedDay day;
  final int dayIndex;
  final void Function(int dayIndex, int exIndex) onRemoveExercise;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              day.label.toUpperCase(),
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder, width: 0.5),
            ),
            child: Column(
              children: List.generate(day.exercises.length, (ei) {
                final isLast = ei == day.exercises.length - 1;
                return _ExerciseRow(
                  exercise: day.exercises[ei],
                  isLast: isLast,
                  onRemove: () => onRemoveExercise(dayIndex, ei),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    required this.exercise,
    required this.isLast,
    required this.onRemove,
  });

  final ParsedExercise exercise;
  final bool isLast;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final detail = _detail(exercise);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (detail.isNotEmpty)
                      Text(
                        detail,
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close,
                    color: AppColors.textSecondary, size: 18),
                onPressed: onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(
              height: 1, thickness: 0.5, color: AppColors.cardBorder,
              indent: 16, endIndent: 16),
      ],
    );
  }

  String _detail(ParsedExercise ex) {
    final parts = <String>[];
    if (ex.reps != null) {
      parts.add('${ex.sets} × ${ex.reps}');
    } else {
      parts.add('${ex.sets} sets');
    }
    if (ex.weightKg != null) {
      final w = ex.weightKg!;
      parts.add('@ ${w % 1 == 0 ? w.toInt() : w} kg');
    }
    if (ex.durationSeconds != null) {
      parts.add('${ex.durationSeconds}s');
    }
    return parts.join('  ');
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.totalExercises, required this.onSave});

  final int totalExercises;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, 16 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border:
            Border(top: BorderSide(color: AppColors.cardBorder, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$totalExercises exercise${totalExercises == 1 ? '' : 's'}',
            style: GoogleFonts.outfit(
                fontSize: 13, color: AppColors.textSecondary),
          ),
          ElevatedButton(
            onPressed: totalExercises == 0 ? null : onSave,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 48),
            ),
            child: const Text('Save routine'),
          ),
        ],
      ),
    );
  }
}
