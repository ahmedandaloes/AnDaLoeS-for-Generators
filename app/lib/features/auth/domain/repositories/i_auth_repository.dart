import '../entities/app_user.dart';

abstract class IAuthRepository {
  Future<AppUser?> currentUser();
  Future<void> signInWithEmailPassword(String email, String password);
  Future<void> signUpWithEmailPassword(String email, String password);
  Future<void> signOut();
  Future<void> upgradeAnonymous(String email, String password);
  Stream<AppUser?> authStateChanges();
}
