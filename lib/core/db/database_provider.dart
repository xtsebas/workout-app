import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'database.dart';

part 'database_provider.g.dart';

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
}

@riverpod
class WeightUnit extends _$WeightUnit {
  @override
  Future<String> build() async {
    final db = ref.watch(appDatabaseProvider);
    final settings = await db.select(db.appSettings).getSingle();
    return settings.weightUnit;
  }

  Future<void> toggle() async {
    final db = ref.read(appDatabaseProvider);
    final next = state.value == 'kg' ? 'lbs' : 'kg';
    await db.setWeightUnit(next);
    state = AsyncData(next);
  }
}
