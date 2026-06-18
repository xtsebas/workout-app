import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/db/database.dart';
import '../../core/db/database_provider.dart';

part 'wger_service.g.dart';

class WgerSearchResult {
  const WgerSearchResult({
    required this.id,
    required this.name,
    this.category,
    this.imageUrl,
  });

  final int id;
  final String name;
  final String? category;
  final String? imageUrl;
}

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

@riverpod
Future<List<WgerSearchResult>> exerciseSearch(Ref ref, String query) =>
    ref.watch(wgerServiceProvider).searchExercises(query);

@Riverpod(keepAlive: true)
WgerService wgerService(Ref ref) {
  final dio = Dio(BaseOptions(
    baseUrl: 'https://wger.de/api/v2/',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'Accept': 'application/json',
      'User-Agent': 'WorkoutApp/1.0 (Flutter)',
    },
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

  Future<List<WgerSearchResult>> searchExercises(String query) async {
    if (query.trim().isEmpty) return [];

    // Primary: WGER autocomplete endpoint
    final fromSearch = await _searchViaAutocomplete(query);
    if (fromSearch.isNotEmpty) return fromSearch;

    // Fallback: exercise list with client-side name filtering
    return _searchViaExerciseList(query);
  }

  Future<List<WgerSearchResult>> _searchViaAutocomplete(String query) async {
    try {
      final response = await dio.get(
        'exercise/search/',
        queryParameters: {
          'term': query.trim(),
          'language': 'english',
          'format': 'json',
        },
      );
      if (response.data is! Map<String, dynamic>) return [];
      final data = response.data as Map<String, dynamic>;
      final suggestions = data['suggestions'] as List<dynamic>? ?? [];

      final results = <WgerSearchResult>[];
      for (final s in suggestions) {
        if (s is! Map<String, dynamic>) continue;
        final d = s['data'];
        if (d is! Map<String, dynamic>) continue;
        final rawId = d['base_id'] ?? d['id'];
        if (rawId == null) continue;
        results.add(WgerSearchResult(
          id: (rawId as num).toInt(),
          name: (s['value'] as String?) ?? (d['name'] as String?) ?? '',
          category: d['category'] as String?,
          imageUrl: d['image'] as String?,
        ));
      }
      return results;
    } catch (_) {
      return [];
    }
  }

  Future<List<WgerSearchResult>> _searchViaExerciseList(String query) async {
    final q = query.trim().toLowerCase();

    final response = await dio.get(
      'exerciseinfo/',
      queryParameters: {
        'format': 'json',
        'limit': 20,
        'search': query.trim(),
      },
    );
    if (response.data is! Map<String, dynamic>) return [];
    final data = response.data as Map<String, dynamic>;
    final items = data['results'] as List<dynamic>? ?? [];
    return _parseExerciseInfoItems(items, q);
  }

  List<WgerSearchResult> _parseExerciseInfoItems(
      List<dynamic> items, String q) {
    final results = <WgerSearchResult>[];
    for (final item in items) {
      if (item is! Map<String, dynamic>) continue;
      final rawId = item['id'];
      if (rawId == null) continue;
      final id = (rawId as num).toInt();

      // Find English translation (language id 2)
      final translations = item['translations'] as List<dynamic>? ?? [];
      String? englishName;
      for (final t in translations) {
        if (t is! Map<String, dynamic>) continue;
        if (t['language'] == 2) {
          englishName = t['name'] as String?;
          break;
        }
      }
      if (englishName == null || englishName.isEmpty) continue;
      // Client-side filter guards against unfiltered server responses
      if (!englishName.toLowerCase().contains(q)) continue;

      String? category;
      final cat = item['category'];
      if (cat is Map<String, dynamic>) {
        category = cat['name'] as String?;
      }

      String? imageUrl;
      final images = item['images'] as List<dynamic>? ?? [];
      if (images.isNotEmpty) {
        final img = images.first;
        if (img is Map<String, dynamic>) {
          imageUrl = img['image'] as String?;
        }
      }

      results.add(WgerSearchResult(
        id: id,
        name: englishName,
        category: category,
        imageUrl: imageUrl,
      ));
    }
    return results;
  }
}
