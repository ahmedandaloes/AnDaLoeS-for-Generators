import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/repositories/auth_repository.dart';
import '../../data/repositories/profile_repository.dart';

/// Fetches the user's profile row (full_name, phone, role, avatar_url).
final profileDataProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final uid = ref.read(authRepositoryProvider).currentUserId;
  if (uid == null) return null;
  return ref.read(profileRepositoryProvider).fetchProfileData(uid);
});

/// Customer rental statistics (total, active, completed, spending).
final rentalStatsProvider =
    FutureProvider.autoDispose<Map<String, num>>((ref) async {
  final uid = ref.read(authRepositoryProvider).currentUserId;
  if (uid == null) return {};
  return ref.read(profileRepositoryProvider).fetchRentalStats(uid);
});

/// Counts pending rental requests for generators the current user owns.
final pendingRequestsCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final uid = ref.read(authRepositoryProvider).currentUserId;
  if (uid == null) return 0;
  return ref.read(profileRepositoryProvider).fetchPendingRequestsCount(uid);
});
