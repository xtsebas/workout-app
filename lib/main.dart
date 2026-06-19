import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/env/env.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/web/mobile_only_screen.dart';
import 'shared/services/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
  );
  runApp(const ProviderScope(child: WorkoutApp()));
}

class WorkoutApp extends ConsumerWidget {
  const WorkoutApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    if (!kIsWeb) ref.watch(syncServiceProvider);

    return MaterialApp.router(
      title: 'Workout',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
      builder: (context, child) {
        if (kIsWeb) {
          final width = MediaQuery.of(context).size.width;
          if (width > 600) return const MobileOnlyScreen();
        }
        return child!;
      },
    );
  }
}
