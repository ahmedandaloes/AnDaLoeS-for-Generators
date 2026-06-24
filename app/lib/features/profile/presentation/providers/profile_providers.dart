import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/profile_repository.dart';
import '../../domain/entities/profile.dart';

export '../../data/repositories/profile_repository.dart'
    show profileRepositoryProvider;

final profileProvider =
    FutureProvider.autoDispose.family<Profile?, String>((ref, userId) async {
  return ref.read(profileRepositoryProvider).fetchProfile(userId);
});

final profileStatsProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, userId) async {
  return ref.read(profileRepositoryProvider).fetchStats(userId);
});
