import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase.dart';
import '../../data/repositories/auth_repository.dart';
import '../../domain/entities/app_user.dart';

export '../../data/repositories/auth_repository.dart' show authRepositoryProvider;

/// Resolves the current authenticated AppUser (null if signed out / anonymous).
final currentUserProvider = FutureProvider.autoDispose<AppUser?>((ref) async {
  return ref.read(authRepositoryProvider).currentUser();
});

/// Role string for the current user — drives routing guard decisions.
final currentRoleProvider = FutureProvider.autoDispose<String?>((ref) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return null;
  final data = await supabase
      .from('profiles')
      .select('role')
      .eq('id', uid)
      .maybeSingle();
  return data?['role']?.toString();
});
