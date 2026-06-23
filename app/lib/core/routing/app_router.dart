import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase.dart';
import '../../features/admin/presentation/admin_screen.dart';
import '../../features/auth/presentation/email_login_screen.dart';
import '../../features/reports/presentation/report_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/company/presentation/company_onboarding_screen.dart';
import '../../features/generators/presentation/generator_detail_screen.dart';
import '../../features/generators/presentation/home_screen.dart';
import '../../features/company/presentation/company_profile_screen.dart';
import '../../features/owner_dashboard/presentation/add_generator_screen.dart';
import '../../features/owner_dashboard/presentation/edit_generator_screen.dart';
import '../../features/owner_dashboard/presentation/owner_dashboard_screen.dart';
import '../../features/owner_dashboard/presentation/owner_earnings_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/ratings/presentation/rate_rental_screen.dart';
import '../../features/rental_request/presentation/my_rentals_screen.dart';
import '../../features/rental_request/presentation/rental_request_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: _GoRouterRefreshStream(supabase.auth.onAuthStateChange),
  redirect: (context, state) {
    final loggedIn = supabase.auth.currentSession != null;
    final loc = state.matchedLocation;

    const protected = {
      '/profile',
      '/my-rentals',
      '/owner-dashboard',
      '/company/onboard',
      '/admin',
      '/notifications',
    };
    final needsAuth = protected.contains(loc) ||
        (loc.startsWith('/generators/') && loc.endsWith('/request')) ||
        loc.startsWith('/owner/') ||
        loc.startsWith('/rate/') ||
        loc.startsWith('/report');

    if (!loggedIn && needsAuth) return '/login';
    if (loggedIn && (loc == '/login' || loc == '/dev-login')) return '/';
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/dev-login', builder: (_, __) => const EmailLoginScreen()),
    GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
    GoRoute(
      path: '/notifications',
      builder: (_, __) => const NotificationsScreen(),
    ),
    GoRoute(path: '/my-rentals', builder: (_, __) => const MyRentalsScreen()),
    GoRoute(path: '/admin', builder: (_, __) => const AdminScreen()),
    GoRoute(
      path: '/owner-dashboard',
      builder: (_, __) => const OwnerDashboardScreen(),
    ),
    GoRoute(
      path: '/owner/earnings',
      builder: (_, state) => OwnerEarningsScreen(
        companyId: state.uri.queryParameters['company'] ?? '',
      ),
    ),
    GoRoute(
      path: '/company/onboard',
      builder: (_, __) => const CompanyOnboardingScreen(),
    ),
    GoRoute(
      path: '/generators/:id',
      builder: (_, state) =>
          GeneratorDetailWrapper(id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/generators/:id/request',
      builder: (_, state) =>
          RentalRequestScreen(generatorId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/company/:id',
      builder: (_, state) =>
          CompanyProfileScreen(companyId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/owner/generator/add',
      builder: (_, state) => AddGeneratorScreen(
        companyId: state.uri.queryParameters['company'] ?? '',
      ),
    ),
    GoRoute(
      path: '/owner/generator/:id/edit',
      builder: (_, state) => EditGeneratorScreen(
        generatorId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/rate/:rentalId',
      builder: (_, state) {
        final params = state.uri.queryParameters;
        return RateRentalScreen(
          rentalRequestId: state.pathParameters['rentalId']!,
          rateeId: params['ratee'] ?? '',
          rateeName: params['name'] ?? 'User',
          isOwnerRating: params['owner'] == 'true',
        );
      },
    ),
    GoRoute(
      path: '/report',
      builder: (_, state) {
        final p = state.uri.queryParameters;
        return ReportScreen(
          entityType: p['type'] ?? 'generator',
          entityId: p['id'] ?? '',
          rentalRequestId: p['rental'],
          entityName: p['name'],
        );
      },
    ),
  ],
);

class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream(Stream<AuthState> stream) {
    notifyListeners();
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
