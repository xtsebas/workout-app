import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../models/exercise_type.dart';
import 'pdf_service.dart';

class GroqParserService {
  GroqParserService()
      : _dio = Dio(BaseOptions(
          baseUrl: 'https://api.groq.com/openai/v1/',
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 60),
          headers: {
            'Authorization': 'Bearer ${dotenv.env['GROQ_API_KEY'] ?? ''}',
            'Content-Type': 'application/json',
          },
        ));

  final Dio _dio;

  static const _system = '''
You are a workout routine extractor. Given raw text from a PDF, extract the workout routine.
Respond ONLY with a valid JSON object — no explanation, no markdown.

Required structure:
{
  "name": "routine name or Imported Routine",
  "days": [
    {
      "weekday": 1,
      "label": "Monday",
      "exercises": [
        {
          "name": "exercise name",
          "sets": 3,
          "reps": 10,
          "weightKg": null,
          "durationSeconds": null,
          "type": "bodyweight"
        }
      ]
    }
  ]
}

Rules:
- weekday: 1=Monday 2=Tuesday 3=Wednesday 4=Thursday 5=Friday 6=Saturday 7=Sunday
- type: "weights" if weight given, "bodyweight" for reps without weight, "cardio", "timed"
- weightKg: number in kg (convert lbs if needed), or null
- reps: integer or null
- durationSeconds: integer or null
- Skip non-exercise lines (notes, tips, warmups)
- If no clear day structure, group exercises under weekday 1
''';

  Future<ParsedRoutine> parse(String pdfText, {String fallbackName = 'Imported Routine'}) async {
    final truncated = pdfText.length > 15000
        ? '${pdfText.substring(0, 15000)}\n[truncated]'
        : pdfText;

    final response = await _dio.post(
      'chat/completions',
      data: {
        'model': 'llama-3.1-8b-instant',
        'response_format': {'type': 'json_object'},
        'max_tokens': 2048,
        'messages': [
          {'role': 'system', 'content': _system},
          {
            'role': 'user',
            'content': 'Extract the workout routine from this PDF text:\n\n$truncated',
          },
        ],
      },
    );

    final content = response.data['choices'][0]['message']['content'] as String;
    return _parse(content.trim(), fallbackName);
  }

  ParsedRoutine _parse(String raw, String fallbackName) {
    final Map<String, dynamic> data = jsonDecode(raw);
    final name = (data['name'] as String?)?.trim();
    final rawDays = data['days'] as List<dynamic>? ?? [];

    final days = <ParsedDay>[];
    for (final d in rawDays) {
      if (d is! Map<String, dynamic>) continue;
      final weekday = (d['weekday'] as num?)?.toInt();
      final label = d['label'] as String?;
      if (weekday == null || label == null) continue;

      final day = ParsedDay(weekday: weekday, label: label);

      for (final e in (d['exercises'] as List<dynamic>? ?? [])) {
        if (e is! Map<String, dynamic>) continue;
        final exName = (e['name'] as String?)?.trim();
        if (exName == null || exName.isEmpty) continue;

        day.exercises.add(ParsedExercise(
          name: exName,
          type: _type((e['type'] as String?) ?? 'bodyweight', (e['weightKg'] as num?)?.toDouble()),
          sets: (e['sets'] as num?)?.toInt() ?? 3,
          reps: (e['reps'] as num?)?.toInt(),
          weightKg: (e['weightKg'] as num?)?.toDouble(),
          durationSeconds: (e['durationSeconds'] as num?)?.toInt(),
        ));
      }

      if (day.exercises.isNotEmpty) days.add(day);
    }

    return ParsedRoutine(
      name: (name != null && name.isNotEmpty) ? name : fallbackName,
      days: days,
    );
  }

  ExerciseType _type(String raw, double? weight) => switch (raw.toLowerCase()) {
        'weights' => ExerciseType.weights,
        'cardio'  => ExerciseType.cardio,
        'timed'   => ExerciseType.timed,
        _         => weight != null ? ExerciseType.weights : ExerciseType.bodyweight,
      };
}
