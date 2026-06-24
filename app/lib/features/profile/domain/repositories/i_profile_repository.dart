import '../entities/profile.dart';

abstract class IProfileRepository {
  Future<Profile?> fetchProfile(String userId);
  Future<void> updateProfile(String userId, Map<String, dynamic> data);
  Future<Map<String, dynamic>> fetchStats(String userId);
}
