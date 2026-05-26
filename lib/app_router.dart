import 'package:go_router/go_router.dart';

import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/trips/trip_history_screen.dart';
import 'screens/trips/trip_detail_screen.dart';
import 'screens/reports/reports_screen.dart';
import 'screens/vehicle_health/vehicle_health_screen.dart';
import 'screens/device_pairing/device_pairing_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/live_trip/live_trip_screen.dart';
import 'widgets/common/app_shell.dart';
import 'models/models.dart';

abstract class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const dashboard = '/dashboard';
  static const trips = '/trips';
  static const tripDetail = '/trips/:id';
  static const reports = '/reports';
  static const vehicleHealth = '/health';
  static const devicePairing = '/pairing';
  static const profile = '/profile';
  static const liveTrip = '/live-trip';

  // Helper: build a typed trip-detail path
  static String tripDetailPath(String tripId) => '/trips/$tripId';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  routes: [
    // ── Unauthenticated / standalone screens ─────────────────────────────
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.register,
      builder: (context, state) => const RegisterScreen(),
    ),

    // ── Live trip — full-screen, no bottom nav ────────────────────────────
    GoRoute(
      path: AppRoutes.liveTrip,
      builder: (context, state) => const LiveTripScreen(),
    ),

    // ── Device pairing — full-screen, no bottom nav ───────────────────────
    GoRoute(
      path: AppRoutes.devicePairing,
      builder: (context, state) => const DevicePairingScreen(),
    ),

    // ── Shell (bottom nav) ────────────────────────────────────────────────
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: AppRoutes.dashboard,
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: AppRoutes.trips,
          builder: (context, state) => const TripHistoryScreen(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) {
                // Accept a pre-loaded TripModel via extra to avoid repo lookup,
                // or fall back to loading by id inside the screen.
                final trip =
                    state.extra is TripModel ? state.extra as TripModel : null;
                return TripDetailScreen(
                  tripId: state.pathParameters['id']!,
                  trip: trip,
                );
              },
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.reports,
          builder: (context, state) => const ReportsScreen(),
        ),
        GoRoute(
          path: AppRoutes.vehicleHealth,
          builder: (context, state) => const VehicleHealthScreen(),
        ),
        GoRoute(
          path: AppRoutes.profile,
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),
  ],
);
