import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/db/database.dart';
import '../../core/db/database_provider.dart';
import '../../core/theme/app_colors.dart';
import 'routines_provider.dart';

class RoutineListScreen extends ConsumerWidget {
  const RoutineListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routinesAsync = ref.watch(allRoutinesProvider);
    final activeId = ref.watch(activeRoutineNotifierProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Routines'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              ref.read(routineBuilderProvider.notifier).reset();
              context.push('/routines/create');
            },
          ),
        ],
      ),
      body: routinesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (routines) {
          if (routines.isEmpty) {
            return _EmptyState(
              onCreate: () {
                ref.read(routineBuilderProvider.notifier).reset();
                context.push('/routines/create');
              },
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: routines.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _RoutineCard(
              routine: routines[i],
              isActive: routines[i].id == activeId,
              onSetActive: () => ref
                  .read(activeRoutineNotifierProvider.notifier)
                  .setActive(routines[i].id),
              onDelete: () => _confirmDelete(context, ref, routines[i],
                  isActive: routines[i].id == activeId),
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Routine routine, {
    required bool isActive,
  }) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Delete "${routine.name}"?',
          style: GoogleFonts.outfit(
              color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'This will delete the routine and all its days and exercises.',
          style:
              GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete',
                style: GoogleFonts.outfit(color: AppColors.danger)),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed != true) return;
      await ref.read(appDatabaseProvider).deleteRoutine(routine.id);
      if (isActive) {
        await ref
            .read(activeRoutineNotifierProvider.notifier)
            .setActive(null);
      }
    });
  }
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({
    required this.routine,
    required this.isActive,
    required this.onSetActive,
    required this.onDelete,
  });

  final Routine routine;
  final bool isActive;
  final VoidCallback onSetActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? AppColors.accent : AppColors.cardBorder,
          width: isActive ? 1.5 : 0.5,
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          routine.name,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: isActive
            ? Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Active',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.accent,
                  ),
                ),
              )
            : null,
        trailing: PopupMenuButton<_RoutineAction>(
          icon: const Icon(Icons.more_vert,
              color: AppColors.textSecondary, size: 20),
          color: AppColors.surface2,
          onSelected: (action) {
            switch (action) {
              case _RoutineAction.setActive:
                onSetActive();
              case _RoutineAction.delete:
                onDelete();
            }
          },
          itemBuilder: (_) => [
            if (!isActive)
              PopupMenuItem(
                value: _RoutineAction.setActive,
                child: Text('Set as active',
                    style: GoogleFonts.outfit(color: AppColors.textPrimary)),
              ),
            PopupMenuItem(
              value: _RoutineAction.delete,
              child: Text('Delete',
                  style: GoogleFonts.outfit(color: AppColors.danger)),
            ),
          ],
        ),
      ),
    );
  }
}

enum _RoutineAction { setActive, delete }

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_outlined,
                color: AppColors.textSecondary, size: 48),
            const SizedBox(height: 20),
            Text(
              'No routines yet',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first routine to start\ntracking your workouts.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: onCreate,
              child: const Text('Create routine'),
            ),
          ],
        ),
      ),
    );
  }
}
