import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/generators/presentation/home_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';

/// App router. Redirects unauthenticated users to /login and refreshes
/// whenever Supabase auth state changes.
final appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: _GoRouterRefreshStream(supabase.auth.onAuthStateChange),
  redirect: (context, state) {
    final loggedIn = supabase.auth.currentSession != null;
    final loggingIn = state.matchedLocation == '/login';

    if (!loggedIn) return loggingIn ? null : '/login';
    if (loggingIn) return '/';
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
  ],
);

/// Bridges a Stream to a Listenable so GoRouter can re-evaluate redirects.
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
