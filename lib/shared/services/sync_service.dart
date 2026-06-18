import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/db/database.dart';
import '../../core/db/database_provider.dart';

part 'sync_service.g.dart';

@Riverpod(keepAlive: true)
Stream<bool> connectivityStatus(Ref ref) {
  return Connectivity().onConnectivityChanged.map(
    (results) => results.any((r) => r != ConnectivityResult.none),
  );
}

@Riverpod(keepAlive: true)
SyncService syncService(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final service = SyncService(db: db);

  ref.listen<AsyncValue<bool>>(connectivityStatusProvider, (prev, next) {
    final isOnline = next.valueOrNull ?? false;
    if (isOnline) service.syncPending();
  });

  return service;
}

class SyncService {
  SyncService({required this.db});

  final AppDatabase db;
  bool _isSyncing = false;

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> syncPending() async {
    if (_isSyncing) return;
    final user = _client.auth.currentUser;
    if (user == null) return;

    _isSyncing = true;
    try {
      await _syncWorkoutLogs(user.id);
    } catch (_) {
      // Will retry on next connectivity change
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _syncWorkoutLogs(String userId) async {
    final unsyncedLogs = await db.getUnsyncedLogs();

    for (final log in unsyncedLogs) {
      final logData = {
        'user_id': userId,
        'local_id': log.id,
        'date': log.date.toIso8601String(),
        'weekday': log.weekday,
        'duration_minutes': log.durationMinutes,
        'is_completed': log.isCompleted,
      };

      final response = await _client
          .from('workout_logs')
          .upsert(logData, onConflict: 'user_id,local_id')
          .select('id')
          .single();

      final remoteId = response['id'].toString();
      await db.markLogSynced(log.id, remoteId);

      final entries = await db.getEntriesForLogSync(log.id);
      for (final entry in entries) {
        final entryData = {
          'user_id': userId,
          'workout_log_id': remoteId,
          'local_id': entry.id,
          'exercise_slot_order': entry.exerciseSlotOrder,
          'exercise_name': entry.exerciseName,
          'exercise_type': entry.exerciseType.name,
          'set_number': entry.setNumber,
          'reps': entry.reps,
          'weight_kg': entry.weightKg,
          'duration_seconds': entry.durationSeconds,
          'distance_km': entry.distanceKm,
          'heart_rate': entry.heartRate,
        };

        final entryResponse = await _client
            .from('set_log_entries')
            .upsert(entryData, onConflict: 'user_id,local_id')
            .select('id')
            .single();

        await db.markEntrySynced(entry.id, entryResponse['id'].toString());
      }
    }
  }
}
