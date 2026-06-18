import 'package:pdfrx/pdfrx.dart';

import '../models/exercise_type.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class ParsedExercise {
  ParsedExercise({
    required this.name,
    required this.type,
    required this.sets,
    this.reps,
    this.weightKg,
    this.durationSeconds,
  });

  String name;
  ExerciseType type;
  int sets;
  int? reps;
  double? weightKg;
  int? durationSeconds;
}

class ParsedDay {
  ParsedDay({required this.weekday, required this.label})
      : exercises = [];

  final int weekday;
  final String label;
  final List<ParsedExercise> exercises;
}

class ParsedRoutine {
  const ParsedRoutine({required this.name, required this.days});

  final String name;
  final List<ParsedDay> days;
}

// ── Service ───────────────────────────────────────────────────────────────────

class PdfService {
  const PdfService();

  Future<String> extractText(String filePath) async {
    final doc = await PdfDocument.openFile(filePath);
    try {
      final buf = StringBuffer();
      for (final page in doc.pages) {
        final pt = await page.loadText();
        buf.writeln(pt.fullText);
      }
      return buf.toString();
    } finally {
      doc.dispose();
    }
  }

  ParsedRoutine parseRoutineText(
    String text, {
    String routineName = 'Imported Routine',
  }) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final days = <ParsedDay>[];
    ParsedDay? current;

    for (final line in lines) {
      final wd = _detectWeekday(line);
      if (wd != null) {
        current = ParsedDay(weekday: wd, label: _weekdayLabel(wd));
        days.add(current);
        continue;
      }
      if (current != null) {
        final ex = _parseExercise(line);
        if (ex != null) current.exercises.add(ex);
      }
    }

    return ParsedRoutine(
      name: routineName,
      days: days.where((d) => d.exercises.isNotEmpty).toList(),
    );
  }

  // ── Day detection ─────────────────────────────────────────────────────────

  static const _weekdayMap = <String, int>{
    'monday': 1,    'lunes': 1,
    'tuesday': 2,   'martes': 2,
    'wednesday': 3, 'miércoles': 3, 'miercoles': 3,
    'thursday': 4,  'jueves': 4,
    'friday': 5,    'viernes': 5,
    'saturday': 6,  'sábado': 6,   'sabado': 6,
    'sunday': 7,    'domingo': 7,
  };

  int? _detectWeekday(String line) {
    if (line.length > 50) return null;
    final lower = line.toLowerCase();
    for (final entry in _weekdayMap.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return null;
  }

  // ── Exercise parsing ──────────────────────────────────────────────────────

  // "Squat 4x10" / "Squat 4x10 @ 80kg" / "Squat 4X10@80kg"
  static final _sxrPattern = RegExp(
    r'^[-•*\s]*(.+?)\s+(\d+)\s*[xX×]\s*(\d+)'
    r'(?:\s*@\s*(\d+(?:\.\d+)?)\s*(?:kg|lbs?))?$',
    caseSensitive: false,
  );

  // "Squat 4 sets x 10 reps @ 80 kg"
  static final _setsRepsPattern = RegExp(
    r'^[-•*\s]*(.+?)\s+(\d+)\s+(?:sets?|series?)\s+[xX×]\s+(\d+)'
    r'(?:\s+(?:reps?|repeticiones?))?'
    r'(?:\s*@\s*(\d+(?:\.\d+)?)\s*(?:kg|lbs?))?$',
    caseSensitive: false,
  );

  ParsedExercise? _parseExercise(String line) {
    if (line.length < 4) return null;
    final m1 = _setsRepsPattern.firstMatch(line);
    if (m1 != null) return _build(m1);
    final m2 = _sxrPattern.firstMatch(line);
    if (m2 != null) return _build(m2);
    return null;
  }

  ParsedExercise _build(RegExpMatch m) {
    final name  = (m.group(1) ?? '').trim();
    final sets  = int.tryParse(m.group(2) ?? '') ?? 3;
    final reps  = int.tryParse(m.group(3) ?? '');
    final wRaw  = m.group(4);
    final weight = wRaw != null ? double.tryParse(wRaw) : null;
    return ParsedExercise(
      name:    name,
      type:    weight != null ? ExerciseType.weights : ExerciseType.bodyweight,
      sets:    sets,
      reps:    reps,
      weightKg: weight,
    );
  }

  static String _weekdayLabel(int wd) {
    const labels = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    return labels[(wd - 1).clamp(0, 6)];
  }
}
