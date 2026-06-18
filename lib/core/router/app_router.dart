import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/db/database.dart';
import '../../features/auth/auth_provider.dart';
import '../../features/auth/sign_in_screen.dart';
import '../../features/auth/sign_up_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/progress/progress_screen.dart';
import '../../features/routines/create_routine_screen.dart';
import '../../features/routines/exercise_search_screen.dart';
import '../../features/routines/pdf_import_screen.dart';
import '../../features/routines/routine_list_screen.dart';
import '../../features/today/today_screen.dart';
import '../../features/workout/active_workout_screen.dart';
import '../../features/workout/exercise_detail_screen.dart';
import 'scaffold_with_nav_bar.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier();
  ref.listen(authStateChangesProvider, (_, _) => refreshNotifier.notify());

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final hasSession = Supabase.instance.client.auth.currentSession != null;
      final isAuthRoute = state.matchedLocation == '/sign-in' ||
          state.matchedLocation == '/sign-up';

      if (!hasSession && !isAuthRoute) return '/sign-in';
      if (hasSession && isAuthRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/sign-up',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/workout/active',
        builder: (context, state) => const ActiveWorkoutScreen(),
      ),
      GoRoute(
        path: '/workout/exercise',
        builder: (context, state) =>
            ExerciseDetailScreen(slot: state.extra! as ExerciseSlot),
      ),
      GoRoute(
        path: '/routines',
        builder: (context, state) => const RoutineListScreen(),
      ),
      GoRoute(
        path: '/routines/create',
        builder: (context, state) => const CreateRoutineScreen(),
      ),
      GoRoute(
        path: '/routines/exercise/search',
        builder: (context, state) =>
            ExerciseSearchScreen(weekday: state.extra! as int),
      ),
      GoRoute(
        path: '/routines/pdf-import',
        builder: (context, state) => const PdfImportScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ScaffoldWithNavBar(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const TodayScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/progress',
                builder: (context, state) => const ProgressScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Notifies go_router's `refreshListenable` so it re-evaluates `redirect`
/// whenever the Supabase auth state changes.
class _RouterRefreshNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
