import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/db/database.dart';
import '../../core/db/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/models/exercise_type.dart';
import '../../shared/services/wger_service.dart';
import 'routines_provider.dart';

class ExerciseSearchScreen extends ConsumerStatefulWidget {
  const ExerciseSearchScreen({super.key, required this.weekday});

  final int weekday;

  @override
  ConsumerState<ExerciseSearchScreen> createState() =>
      _ExerciseSearchScreenState();
}

class _ExerciseSearchScreenState
    extends ConsumerState<ExerciseSearchScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final weekdayName = _weekdayLabel(widget.weekday);

    return Scaffold(
      appBar: AppBar(
        title: Text('Add to $weekdayName'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search exercises…',
                prefixIcon: const Icon(Icons.search,
                    color: AppColors.textSecondary, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close,
                            color: AppColors.textSecondary, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
      body: _query.isEmpty
          ? _HintState()
          : _SearchResults(
              query: _query,
              onSelect: (result) => _showSlotConfig(context, result),
              onCreateCustom: (name) => _showCustomConfig(context, name),
            ),
    );
  }

  void _showCustomConfig(BuildContext context, String name) {
    _showSlotConfig(
      context,
      WgerSearchResult(id: 0, name: name),
      isCustom: true,
    );
  }

  Future<void> _saveCustomExercise(String name, ExerciseType type) async {
    final db = ref.read(appDatabaseProvider);
    await db.insertCustomExercise(CustomExercisesCompanion(
      name: Value(name),
      exerciseType: Value(type),
    ));
  }

  void _showSlotConfig(BuildContext context, WgerSearchResult result, {bool isCustom = false}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SlotConfigSheet(
        result: result,
        weekday: widget.weekday,
        isCustom: isCustom,
        onAdd: (slot) {
          if (isCustom) {
            _saveCustomExercise(slot.exerciseName, slot.exerciseType);
          }
          ref.read(routineBuilderProvider.notifier).addSlot(widget.weekday, slot);
          Navigator.of(ctx).pop();
          context.pop();
        },
      ),
    );
  }
}

// ── Search results ────────────────────────────────────────────────────────────

class _SearchResults extends ConsumerWidget {
  const _SearchResults({
    required this.query,
    required this.onSelect,
    required this.onCreateCustom,
  });

  final String query;
  final void Function(WgerSearchResult) onSelect;
  final void Function(String name) onCreateCustom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(exerciseSearchProvider(query));
    final db = ref.watch(appDatabaseProvider);

    return resultsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Search error: $e',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (wgerResults) {
        return FutureBuilder<List<CustomExercise>>(
          future: db.searchCustomExercises(query),
          builder: (context, snap) {
            final customResults = snap.data ?? [];
            final customAsWger = customResults.map((c) =>
                WgerSearchResult(id: 0, name: c.name, category: 'Custom')).toList();

            final wgerNames = wgerResults.map((r) => r.name.toLowerCase()).toSet();
            final deduped = customAsWger
                .where((c) => !wgerNames.contains(c.name.toLowerCase()))
                .toList();

            final allResults = [...deduped, ...wgerResults];

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: allResults.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                if (i == allResults.length) {
                  return _CreateCustomTile(
                    name: query,
                    onTap: () => onCreateCustom(query),
                  );
                }
                final r = allResults[i];
                return _ResultTile(
                  result: r,
                  onTap: () => r.category == 'Custom'
                      ? onCreateCustom(r.name)
                      : onSelect(r),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result, required this.onTap});

  final WgerSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder, width: 0.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.name,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (result.category != null)
                    Text(
                      result.category!,
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
      ),
    );
  }
}

class _CreateCustomTile extends StatelessWidget {
  const _CreateCustomTile({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3), width: 1),
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
              child: const Icon(Icons.add, color: AppColors.accent, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create "$name"',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                  Text(
                    'Custom exercise',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HintState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Type to search exercises from WGER database',
        style: GoogleFonts.outfit(
            fontSize: 14, color: AppColors.textSecondary),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ── Slot config bottom sheet ──────────────────────────────────────────────────

class _SlotConfigSheet extends StatefulWidget {
  const _SlotConfigSheet({
    required this.result,
    required this.weekday,
    required this.onAdd,
    this.isCustom = false,
  });

  final WgerSearchResult result;
  final int weekday;
  final void Function(SlotConfig) onAdd;
  final bool isCustom;

  @override
  State<_SlotConfigSheet> createState() => _SlotConfigSheetState();
}

class _SlotConfigSheetState extends State<_SlotConfigSheet> {
  ExerciseType _type = ExerciseType.weights;
  final _setsCtrl = TextEditingController(text: '3');
  final _repsCtrl = TextEditingController(text: '10');
  final _durationCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();

  @override
  void dispose() {
    _setsCtrl.dispose();
    _repsCtrl.dispose();
    _durationCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.result.name,
            style: GoogleFonts.outfit(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),

          // Type selector
          Text('Type',
              style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ExerciseType.values.map((t) {
              final selected = _type == t;
              return GestureDetector(
                onTap: () => setState(() => _type = t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.accent
                        : AppColors.surface2,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected
                          ? AppColors.accent
                          : AppColors.divider,
                    ),
                  ),
                  child: Text(
                    t.name,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: selected
                          ? AppColors.onAccent
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Sets + reps/duration
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _setsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Sets'),
                ),
              ),
              const SizedBox(width: 12),
              if (_type == ExerciseType.weights ||
                  _type == ExerciseType.bodyweight)
                Expanded(
                  child: TextField(
                    controller: _repsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Reps'),
                  ),
                )
              else
                Expanded(
                  child: TextField(
                    controller: _durationCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Duration (s)'),
                  ),
                ),
            ],
          ),
          if (_type == ExerciseType.weights) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _weightCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'Default weight (kg, optional)'),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _submit,
            child: Text('Add to ${_weekdayLabel(widget.weekday)}'),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final sets = int.tryParse(_setsCtrl.text) ?? 3;
    widget.onAdd(SlotConfig(
      exerciseName: widget.result.name,
      wgerExerciseId: widget.isCustom ? null : widget.result.id,
      exerciseType: _type,
      sets: sets,
      reps: _type == ExerciseType.weights || _type == ExerciseType.bodyweight
          ? int.tryParse(_repsCtrl.text)
          : null,
      durationSeconds:
          _type == ExerciseType.cardio || _type == ExerciseType.timed
              ? int.tryParse(_durationCtrl.text)
              : null,
      weightKg: _type == ExerciseType.weights
          ? double.tryParse(_weightCtrl.text)
          : null,
    ));
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _weekdayLabel(int weekday) {
  const labels = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];
  return labels[(weekday - 1).clamp(0, 6)];
}
