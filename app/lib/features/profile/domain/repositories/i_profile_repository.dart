import 'dart:typed_data';

import '../entities/profile.dart';

abstract class IProfileRepository {
  Future<Profile?> fetchProfile(String userId);
  Future<void> updateProfile(String userId, Map<String, dynamic> data);
  Future<Map<String, dynamic>> fetchStats(String userId);

  // Extended profile screen operations
  Future<Map<String, dynamic>?> fetchProfileData(String uid);
  Future<Map<String, num>> fetchRentalStats(String uid);
  Future<int> fetchPendingRequestsCount(String uid);
  Future<String> uploadAvatar(String uid, Uint8List bytes, String ext);
  Future<void> signOut();
  Future<void> upgradeAnonymousAccount(String email, String password);
}
