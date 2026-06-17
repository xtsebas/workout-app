import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/db/database.dart';
import '../../core/db/database_provider.dart';

part 'wger_service.g.dart';

class WgerExerciseInfo {
  const WgerExerciseInfo({
    required this.wgerId,
    required this.name,
    this.description,
    this.imageUrl,
    this.muscleGroup,
  });

  final int wgerId;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? muscleGroup;
}

@riverpod
Future<WgerExerciseInfo?> exerciseInfo(Ref ref, int wgerId) =>
    ref.watch(wgerServiceProvider).getExerciseInfo(wgerId);

@Riverpod(keepAlive: true)
WgerService wgerService(Ref ref) {
  final dio = Dio(BaseOptions(
    baseUrl: 'https://wger.de/api/v2/',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));
  return WgerService(dio: dio, db: ref.watch(appDatabaseProvider));
}

class WgerService {
  const WgerService({required this.dio, required this.db});

  final Dio dio;
  final AppDatabase db;

  static const _cacheTtl = Duration(days: 7);

  Future<WgerExerciseInfo?> getExerciseInfo(int wgerId) async {
    final cached = await db.getCachedExercise(wgerId);
    if (cached != null &&
        DateTime.now().difference(cached.cachedAt) < _cacheTtl) {
      return WgerExerciseInfo(
        wgerId: cached.wgerId,
        name: cached.name,
        description: cached.description,
        imageUrl: cached.imageUrl,
        muscleGroup: cached.muscleGroup,
      );
    }

    try {
      final response = await dio.get(
        'exerciseinfo/$wgerId/',
        queryParameters: {'format': 'json'},
      );
      final data = response.data as Map<String, dynamic>;

      String name = data['name'] as String? ?? '';
      String? description;
      final translations = data['translations'] as List<dynamic>? ?? [];
      final english = translations.cast<Map<String, dynamic>>().firstWhere(
            (t) => t['language'] == 2,
            orElse: () => {},
          );
      if (english.isNotEmpty) {
        final eName = english['name'] as String? ?? '';
        if (eName.isNotEmpty) name = eName;
        description = english['description'] as String?;
        if (description != null) {
          description = description.replaceAll(RegExp(r'<[^>]*>'), '').trim();
          if (description.isEmpty) description = null;
        }
      }

      String? imageUrl;
      final images = data['images'] as List<dynamic>? ?? [];
      if (images.isNotEmpty) {
        final img = images.first as Map<String, dynamic>;
        imageUrl = img['image'] as String?;
      }

      String? muscleGroup;
      final muscles = data['muscles'] as List<dynamic>? ?? [];
      if (muscles.isNotEmpty) {
        final m = muscles.first as Map<String, dynamic>;
        muscleGroup = m['name_en'] as String?;
      }

      await db.upsertCachedExercise(ExerciseCacheCompanion(
        wgerId: Value(wgerId),
        name: Value(name),
        description: Value(description),
        imageUrl: Value(imageUrl),
        muscleGroup: Value(muscleGroup),
        cachedAt: Value(DateTime.now()),
      ));

      return WgerExerciseInfo(
        wgerId: wgerId,
        name: name,
        description: description,
        imageUrl: imageUrl,
        muscleGroup: muscleGroup,
      );
    } catch (_) {
      if (cached != null) {
        return WgerExerciseInfo(
          wgerId: cached.wgerId,
          name: cached.name,
          description: cached.description,
          imageUrl: cached.imageUrl,
          muscleGroup: cached.muscleGroup,
        );
      }
      return null;
    }
  }
}
