import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/db/database_provider.dart';
import '../../core/theme/app_colors.dart';

class EditExercisesScreen extends ConsumerStatefulWidget {
  const EditExercisesScreen({super.key});

  @override
  ConsumerState<EditExercisesScreen> createState() =>
      _EditExercisesScreenState();
}

class _EditExercisesScreenState extends ConsumerState<EditExercisesScreen> {
  List<({String name, bool isPerSide})> _exercises = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(appDatabaseProvider);
    final data = await db.getDistinctSlotExercises();
    setState(() {
      _exercises = data;
      _loading = false;
    });
  }

  Future<void> _editName(int index) async {
    final current = _exercises[index];
    final ctrl = TextEditingController(text: current.name);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Rename exercise',
            style: GoogleFonts.outfit(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: GoogleFonts.outfit(color: AppColors.textPrimary),
          decoration: const InputDecoration(labelText: 'Exercise name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    ctrl.dispose();
    if (newName == null || newName.isEmpty || newName == current.name) return;

    final db = ref.read(appDatabaseProvider);
    await db.renameExercise(current.name, newName);
    _load();
  }

  Future<void> _togglePerSide(int index) async {
    final current = _exercises[index];
    final db = ref.read(appDatabaseProvider);
    await db.updateExercisePerSide(current.name, !current.isPerSide);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Exercises')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _exercises.isEmpty
              ? Center(
                  child: Text('No exercises found',
                      style: GoogleFonts.outfit(
                          color: AppColors.textSecondary, fontSize: 14)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: _exercises.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final ex = _exercises[i];
                    return Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.cardBorder, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ex.name,
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (ex.isPerSide)
                                  Text(
                                    'Per side',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      color: AppColors.accent,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              ex.isPerSide
                                  ? Icons.swap_horiz
                                  : Icons.swap_horiz_outlined,
                              color: ex.isPerSide
                                  ? AppColors.accent
                                  : AppColors.textSecondary,
                              size: 20,
                            ),
                            tooltip: ex.isPerSide
                                ? 'Switch to total weight'
                                : 'Switch to per side',
                            onPressed: () => _togglePerSide(i),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                color: AppColors.textSecondary, size: 20),
                            tooltip: 'Rename',
                            onPressed: () => _editName(i),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
