import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase.dart';
import 'app_routes.dart';
import '../dev/page_hub_screen.dart';
import '../../features/admin/presentation/admin_screen.dart';
import '../../features/auth/presentation/email_login_screen.dart';
import '../../features/auth/presentation/email_auth_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/reports/presentation/report_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/company/presentation/company_onboarding_screen.dart';
import '../../features/generators/presentation/generator_detail_screen.dart';
import '../../features/generators/presentation/home_screen.dart';
import '../../features/generators/presentation/map_screen.dart';
import '../../features/company/presentation/company_profile_screen.dart';
import '../../features/owner_dashboard/presentation/add_generator_screen.dart';
import '../../features/owner_dashboard/presentation/edit_generator_screen.dart';
import '../../features/owner_dashboard/presentation/owner_dashboard_screen.dart';
import '../../features/owner_dashboard/presentation/owner_earnings_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/ratings/presentation/rate_rental_screen.dart';
import '../../features/rental_request/presentation/my_rentals_screen.dart';
import '../../features/rental_request/presentation/rental_receipt_screen.dart';
import '../../features/rental_request/presentation/rental_request_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/rental_request/presentation/rental_offer_screen.dart';
import '../../features/rental_request/presentation/invoice_screen.dart';

/// Cached role for the signed-in user (defense-in-depth route gating on top of
/// RLS). Refreshed on every auth state change; null while unknown/loading — in
/// which case routes are allowed and RLS + in-screen gates remain the real guard.
final ValueNotifier<String?> _roleCache = ValueNotifier<String?>(null);

Future<void> _refreshRole() async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) {
    _roleCache.value = null;
    return;
  }
  try {
    final data = await supabase
        .from('profiles')
        .select('role')
        .eq('id', uid)
        .maybeSingle();
    _roleCache.value = data?['role']?.toString();
  } catch (_) {
    _roleCache.value = null;
  }
}

GoRouter buildAppRouter([String initialLocation = '/']) {
  // Keep the cached role in sync with auth changes (and load it once now).
  _refreshRole();
  supabase.auth.onAuthStateChange.listen((_) => _refreshRole());

  return GoRouter(
  initialLocation: initialLocation,
  refreshListenable: Listenable.merge(
      [_GoRouterRefreshStream(supabase.auth.onAuthStateChange), _roleCache]),
  redirect: (context, state) {
    final loggedIn = supabase.auth.currentSession != null;
    final loc = state.matchedLocation;
    final role = _roleCache.value;

    const protected = {
      AppRoutes.profile,
      AppRoutes.myRentals,
      AppRoutes.ownerDashboard,
      AppRoutes.companyOnboard,
      AppRoutes.admin,
      AppRoutes.notifications,
      AppRoutes.pageHub,
    };
    final needsAuth = protected.contains(loc) ||
        (loc.startsWith('/generators/') && loc.endsWith('/request')) ||
        loc.startsWith('/owner/') ||
        loc.startsWith('/rate/') ||
        loc.startsWith('/receipt/') ||
        loc.startsWith('/chat/') ||
        loc.startsWith('/offer/') ||
        loc.startsWith('/invoice/') ||
        loc.startsWith('/report');

    if (!loggedIn && needsAuth) return AppRoutes.login;
    if (loggedIn &&
        (loc == AppRoutes.login ||
            loc == AppRoutes.emailAuth ||
            loc == AppRoutes.devLogin)) {
      return AppRoutes.home;
    }
    // Role gating (defense-in-depth; only when role is known). Admin can access
    // everything. /owner-dashboard stays open (entry to becoming an owner).
    if (loggedIn && role != null) {
      if (loc == AppRoutes.admin && role != 'admin') return AppRoutes.home;
      if (loc.startsWith('/owner/') && role != 'owner' && role != 'admin') {
        return AppRoutes.home;
      }
    }
    return null;
  },
  routes: [
    GoRoute(path: AppRoutes.home, builder: (_, __) => const HomeScreen()),
    GoRoute(path: AppRoutes.map, builder: (_, __) => const MapScreen()),
    GoRoute(path: AppRoutes.onboarding, builder: (_, __) => const OnboardingScreen()),
    GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
    GoRoute(path: AppRoutes.emailAuth, builder: (_, __) => const EmailAuthScreen()),
    GoRoute(path: AppRoutes.devLogin, builder: (_, __) => const EmailLoginScreen()),
    GoRoute(path: AppRoutes.profile, builder: (_, __) => const ProfileScreen()),
    GoRoute(path: AppRoutes.notifications, builder: (_, __) => const NotificationsScreen()),
    GoRoute(path: AppRoutes.myRentals, builder: (_, __) => const MyRentalsScreen()),
    GoRoute(path: AppRoutes.admin, builder: (_, __) => const AdminScreen()),
    GoRoute(path: AppRoutes.ownerDashboard, builder: (_, __) => const OwnerDashboardScreen()),
    GoRoute(path: AppRoutes.companyOnboard, builder: (_, __) => const CompanyOnboardingScreen()),
    GoRoute(path: AppRoutes.pageHub, builder: (_, __) => const PageHubScreen()),
    GoRoute(
      path: AppRoutes.ownerEarningsPath,
      builder: (_, state) => OwnerEarningsScreen(
        companyId: state.uri.queryParameters['company'] ?? '',
      ),
    ),
    GoRoute(
      path: AppRoutes.generatorDetailPath,
      builder: (_, state) =>
          GeneratorDetailWrapper(id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: AppRoutes.generatorRequestPath,
      builder: (_, state) =>
          RentalRequestScreen(generatorId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: AppRoutes.companyProfilePath,
      builder: (_, state) =>
          CompanyProfileScreen(companyId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: AppRoutes.addGeneratorPath,
      builder: (_, state) => AddGeneratorScreen(
        companyId: state.uri.queryParameters['company'] ?? '',
        prefill: state.extra as Map<String, dynamic>?,
      ),
    ),
    GoRoute(
      path: AppRoutes.editGeneratorPath,
      builder: (_, state) => EditGeneratorScreen(
        generatorId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: AppRoutes.ratePath,
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
      path: AppRoutes.receiptPath,
      builder: (_, state) => RentalReceiptScreen(
        rentalId: state.pathParameters['rentalId']!,
      ),
    ),
    GoRoute(
      path: AppRoutes.offerPath,
      builder: (_, state) => RentalOfferScreen(
        rentalId: state.pathParameters['rentalId']!,
      ),
    ),
    GoRoute(
      path: AppRoutes.invoicePath,
      builder: (_, state) => InvoiceScreen(
        rentalId: state.pathParameters['rentalId']!,
      ),
    ),
    GoRoute(
      path: AppRoutes.chatPath,
      builder: (_, state) => ChatScreen(
        rentalRequestId: state.pathParameters['rentalId']!,
        otherPartyName: state.uri.queryParameters['name'] ?? 'Chat',
      ),
    ),
    GoRoute(
      path: AppRoutes.reportPath,
      builder: (_, state) {
        final p = state.uri.queryParameters;
        return ReportScreen(
          entityType: p['type'] ?? 'generator',
          entityId: p['id'] ?? '',
          rentalRequestId: p['rental'],
          entityName: p['name'],
          initialReason: p['reason'],
        );
      },
    ),
  ],
);
}

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
