import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/design_tokens.dart';
import '../../presentation/providers/session_provider.dart';
import '../../presentation/screens/analytics/analytics_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/calendar/calendar_screen.dart';
import '../../presentation/screens/dashboard/dashboard_screen.dart';
import '../../presentation/screens/history/history_screen.dart';
import '../../presentation/screens/settings/big_buys_screen.dart';
import '../../presentation/screens/settings/category_management_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/widgets/offline_banner.dart';
import '../../presentation/widgets/reconciling_banner.dart';

// ---------------------------------------------------------------------------
// Route path constants
// ---------------------------------------------------------------------------

abstract final class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const dashboard = '/dashboard';
  static const history = '/history';
  static const calendar = '/calendar';
  static const analytics = '/analytics';
  static const settings = '/settings';

  /// Full-screen category management — outside the shell (no bottom nav).
  static const categories = '/categories';

  /// Full-screen big buys — outside the shell (no bottom nav).
  static const bigBuys = '/big-buys';
}

// ---------------------------------------------------------------------------
// Router provider
// ---------------------------------------------------------------------------

/// The global [GoRouter] provider.
///
/// Watches [sessionProvider] so the router rebuilds and re-evaluates the
/// redirect guard whenever authentication state changes.
final routerProvider = Provider<GoRouter>((ref) {
  // Watch sessionProvider so the router is rebuilt on auth state changes.
  // This triggers redirect re-evaluation on login / logout.
  final sessionAsync = ref.watch(sessionProvider);

  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    debugLogDiagnostics: false,
    redirect: (BuildContext context, GoRouterState state) {
      // Resolve the current session state.
      final session = sessionAsync.value;
      final isInitializing = session?.isInitializing ??
          sessionAsync.isLoading; // treat loading as initializing
      final isLoggedIn = session?.isAuthenticated ?? false;
      final isOnLogin = state.matchedLocation == AppRoutes.login;

      // 1. Still initializing — do not redirect; show whatever is already displayed.
      if (isInitializing || sessionAsync.isLoading) return null;

      // 2. Not logged in and not already on /login or /register → send to /login.
      if (!isLoggedIn && !isOnLogin && state.matchedLocation != AppRoutes.register) return AppRoutes.login;

      // 3. Logged in and on /login → send to /dashboard.
      if (isLoggedIn && isOnLogin) return AppRoutes.dashboard;

      // No redirect needed.
      return null;
    },
    routes: [
      // -----------------------------------------------------------------------
      // Unauthenticated route — outside the shell (no bottom nav)
      // -----------------------------------------------------------------------
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),

      // -----------------------------------------------------------------------
      // Full-screen routes outside the shell (no bottom nav)
      // -----------------------------------------------------------------------
      GoRoute(
        path: AppRoutes.categories,
        builder: (context, state) => const CategoryManagementScreen(),
      ),
      GoRoute(
        path: AppRoutes.bigBuys,
        builder: (context, state) => const BigBuysScreen(),
      ),

      // -----------------------------------------------------------------------
      // Authenticated shell — wraps the 5 main tabs with ScaffoldWithBottomNav
      // -----------------------------------------------------------------------
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ScaffoldWithBottomNav(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.dashboard,
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.history,
                builder: (context, state) => const HistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.calendar,
                builder: (context, state) => const CalendarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.analytics,
                builder: (context, state) => const AnalyticsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

// ---------------------------------------------------------------------------
// ScaffoldWithBottomNav
// ---------------------------------------------------------------------------

/// Shell widget that wraps the five main screens with a persistent bottom
/// navigation bar.
///
/// - Active tab uses [AppColors.primary] (teal).
/// - Inactive tabs use [AppColors.mutedText] (grey).
/// - The bottom nav is hidden on routes outside this shell (e.g. /login,
///   modal sheets, detail screens) — Req 2.4.
class ScaffoldWithBottomNav extends StatelessWidget {
  const ScaffoldWithBottomNav({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Offline and reconciling banners sit above the screen content.
          // They are zero-height when not active (SizedBox.shrink).
          const OfflineBanner(),
          const ReconcilingBanner(),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => _onTap(context, index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.cardPrimary,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.mutedText,
        selectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  void _onTap(BuildContext context, int index) {
    // goBranch navigates to the selected branch, preserving each branch's
    // navigation stack. initialLocation: true resets to the branch root when
    // tapping the already-active tab (standard mobile UX).
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}
