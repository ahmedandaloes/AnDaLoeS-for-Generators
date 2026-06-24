import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/i_auth_repository.dart';

final authRepositoryProvider =
    Provider<IAuthRepository>((_) => AuthRepository());

class AuthRepository implements IAuthRepository {
  @override
  Future<AppUser?> currentUser() async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;
    try {
      final data = await supabase
          .from('profiles')
          .select('id, role, created_at')
          .eq('id', user.id)
          .maybeSingle();
      if (data == null) return null;
      return AppUser.fromMap({...data, 'email': user.email},
          isAnonymous: user.isAnonymous);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> signInWithEmailPassword(String email, String password) async {
    await supabase.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signUpWithEmailPassword(String email, String password) async {
    await supabase.auth.signUp(email: email, password: password);
  }

  @override
  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  @override
  Future<void> upgradeAnonymous(String email, String password) async {
    await supabase.auth.updateUser(
      UserAttributes(email: email, password: password),
    );
  }

  @override
  Stream<AppUser?> authStateChanges() {
    return supabase.auth.onAuthStateChange.map((event) {
      final user = event.session?.user;
      if (user == null) return null;
      return AppUser(
        id: user.id,
        email: user.email,
        role: 'customer',
        isAnonymous: user.isAnonymous,
      );
    });
  }
}
