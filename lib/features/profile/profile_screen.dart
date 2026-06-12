import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database_provider.dart';
import '../auth/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weightUnit = ref.watch(weightUnitProvider);
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: weightUnit.when(
          data: (unit) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Weight unit: $unit',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(weightUnitProvider.notifier).toggle(),
                child: const Text('Toggle unit'),
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: authState.isLoading
                    ? null
                    : () => ref.read(authControllerProvider.notifier).signOut(),
                child: const Text('Sign out'),
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
