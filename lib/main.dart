import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/db/database_provider.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: WorkoutApp()));
}

class WorkoutApp extends StatelessWidget {
  const WorkoutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Workout',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const _DbTestScreen(),
    );
  }
}

/// Temporary screen to verify the Drift database and AppSettings provider.
/// Replaced by the navigation shell in the next step.
class _DbTestScreen extends ConsumerWidget {
  const _DbTestScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weightUnit = ref.watch(weightUnitProvider);

    return Scaffold(
      body: Center(
        child: weightUnit.when(
          data: (unit) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Weight unit: $unit', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(weightUnitProvider.notifier).toggle(),
                child: const Text('Toggle unit'),
              ),
            ],
          ),
          loading: () => const CircularProgressIndicator(),
          error: (e, st) => Text('Error: $e'),
        ),
      ),
    );
  }
}
