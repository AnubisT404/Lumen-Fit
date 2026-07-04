import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/modal_utils.dart';
import '../screens/auth/auth_screen.dart';
import '../screens/diary/diary_screen.dart';
import '../screens/coach/coach_screen.dart';
import '../screens/workouts/workouts_screen.dart';
import '../screens/menu/menu_screen.dart';
import '../screens/measurements/measurements_screen.dart';
import '../screens/nutrition/nutrition_detail_screen.dart';
import '../screens/nutrition/goals_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/new_workout/new_workout_screen.dart';
import '../screens/add_food/add_food_screen.dart';
import '../screens/plans/plans_screen.dart';
import '../screens/plans/plan_builder_screen.dart';
import '../screens/plans/routine_builder_screen.dart';
import '../screens/setup/setup_screen.dart';
import '../screens/dev/dev_tour_screen.dart';
import '../services/auth_service.dart';
import '../utils/date_utils.dart';
import '../widgets/app_shell.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Tracks whether onboarding has been completed (set once at startup).
bool _profileSetupDone = true; // default true to avoid flash; set properly in init

/// Must be called before runApp to load the onboarding flag.
Future<void> initOnboardingState() async {
  final prefs = await SharedPreferences.getInstance();
  _profileSetupDone = prefs.getBool('profile_setup_done') ?? false;
}

/// Called from setup screen when profile is saved.
Future<void> markOnboardingComplete() async {
  _profileSetupDone = true;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('profile_setup_done', true);
  RouterRefreshNotifier.instance.refresh();
}

/// Builds a smooth slide-over page transition.
/// Uses a simple right-to-left slide WITHOUT the parallax effect on the old page,
/// preventing bleed-through and reducing compositor work during animation.
Page<void> _buildPage({required LocalKey key, required Widget child}) {
  if (!kIsWeb && Platform.isIOS) {
    return _SlideOverPage(key: key, child: child);
  }
  return MaterialPage(key: key, child: child);
}

/// Custom page that slides in from right and covers the old page completely.
/// Does NOT use CupertinoRouteTransitionMixin to avoid any secondary animation
/// being applied to the previous route (which causes bleed-through/jank).
class _SlideOverPage extends Page<void> {
  final Widget child;

  const _SlideOverPage({required this.child, super.key});

  @override
  Route<void> createRoute(BuildContext context) {
    return _SlideOverRoute(page: this);
  }
}

class _SlideOverRoute extends PageRoute<void> {
  final _SlideOverPage page;

  _SlideOverRoute({required this.page}) : super(settings: page);

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return page.child;
  }

  @override
  bool get opaque => true;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 250);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 200);

  @override
  bool get popGestureEnabled => true;

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
      child: child,
    );
  }

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) => false;

  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) => false;
}

/// Hides native UiKitViews during page transitions to prevent bleed-through.
class _NativeViewTransitionObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is _SlideOverRoute) {
      // Schedule after the build phase completes
      WidgetsBinding.instance.scheduleFrameCallback((_) {
        nativeViewSafe.value = false;
      });
      route.animation?.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          nativeViewSafe.value = true;
        }
      });
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is _SlideOverRoute) {
      WidgetsBinding.instance.scheduleFrameCallback((_) {
        nativeViewSafe.value = false;
      });
      Future.delayed(const Duration(milliseconds: 300), () {
        nativeViewSafe.value = true;
      });
    }
  }
}

/// Notifier to trigger router re-evaluation when auth/onboarding state changes.
class RouterRefreshNotifier extends ChangeNotifier {
  static final instance = RouterRefreshNotifier();
  void refresh() => notifyListeners();
}

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/diary',
  observers: [_NativeViewTransitionObserver()],
  refreshListenable: RouterRefreshNotifier.instance,
  redirect: (context, state) {
    final goingToSetup = state.matchedLocation == '/setup';
    final goingToAuth = state.matchedLocation == '/auth';

    // Auth gate: if auth is enabled and user not logged in, redirect to /auth
    if (AuthService.authEnabled && !AuthService.isLoggedIn && !goingToAuth) {
      return '/auth';
    }

    if (!_profileSetupDone && !goingToSetup && !goingToAuth) return '/setup';
    return null;
  },
  routes: [
    // Auth screen
    GoRoute(
      path: '/auth',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => _buildPage(
        key: state.pageKey,
        child: const AuthScreen(),
      ),
    ),
    // Dev tour (QA screenshots)
    GoRoute(
      path: '/dev-tour',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => _buildPage(
        key: state.pageKey,
        child: const DevTourScreen(),
      ),
    ),
    // Full-screen routes (no bottom nav) — native platform push
    GoRoute(
      path: '/measurements',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => _buildPage(
        key: state.pageKey,
        child: const MeasurementsScreen(),
      ),
    ),
    GoRoute(
      path: '/nutrition',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => _buildPage(
        key: state.pageKey,
        child: const NutritionDetailScreen(),
      ),
    ),
    GoRoute(
      path: '/nutrition/goals',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => _buildPage(
        key: state.pageKey,
        child: const GoalsScreen(),
      ),
    ),
    GoRoute(
      path: '/chat',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => _buildPage(
        key: state.pageKey,
        child: ChatScreen(
          initialPrompt: state.uri.queryParameters['prompt'],
        ),
      ),
    ),
    GoRoute(
      path: '/new-workout',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => _buildPage(
        key: state.pageKey,
        child: NewWorkoutScreen(
          initialType: state.uri.queryParameters['type'] ?? 'strength',
          planRoutineId: state.uri.queryParameters['plan'],
          initialExercise: state.uri.queryParameters['exercise'],
          initialCategory: state.uri.queryParameters['category'],
        ),
      ),
    ),
    GoRoute(
      path: '/setup',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => _buildPage(
        key: state.pageKey,
        child: const SetupScreen(),
      ),
    ),
    GoRoute(
      path: '/add-food',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => _buildPage(
        key: state.pageKey,
        child: AddFoodScreen(
          mealType: state.uri.queryParameters['meal'] ?? 'breakfast',
          date: state.uri.queryParameters['date'] ?? todayDateString(),
          editItemId: state.uri.queryParameters['edit'],
        ),
      ),
    ),
    GoRoute(
      path: '/plans',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => _buildPage(
        key: state.pageKey,
        child: const PlansScreen(),
      ),
    ),
    GoRoute(
      path: '/plans/new',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => _buildPage(
        key: state.pageKey,
        child: PlanBuilderScreen(
          editId: state.uri.queryParameters['edit'],
        ),
      ),
    ),
    GoRoute(
      path: '/routines/new',
      parentNavigatorKey: rootNavigatorKey,
      pageBuilder: (context, state) => _buildPage(
        key: state.pageKey,
        child: RoutineBuilderScreen(
          editId: state.uri.queryParameters['edit'],
        ),
      ),
    ),
    StatefulShellRoute.indexedStack(
      pageBuilder: (context, state, navigationShell) => NoTransitionPage(
        child: AppShell(navigationShell: navigationShell),
      ),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/diary',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DiaryScreen(),
            ),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/coach',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CoachScreen(),
            ),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/workouts',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: WorkoutsScreen(),
            ),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/menu',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MenuScreen(),
            ),
          ),
        ]),
      ],
    ),
  ],
);
