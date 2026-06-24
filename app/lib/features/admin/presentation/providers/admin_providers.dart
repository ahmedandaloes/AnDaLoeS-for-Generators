import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/admin_repository.dart';
import '../../domain/entities/admin_stats.dart';

export '../../data/repositories/admin_repository.dart'
    show adminRepositoryProvider;

final adminStatsProvider =
    FutureProvider.autoDispose<AdminStats>((ref) async {
  return ref.read(adminRepositoryProvider).fetchStats();
});

final adminPendingCompaniesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.read(adminRepositoryProvider).fetchPendingCompanies();
});

final adminAllGeneratorsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.read(adminRepositoryProvider).fetchAllGenerators();
});

final adminAllUsersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.read(adminRepositoryProvider).fetchAllUsers();
});

final adminAllRentalsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String?>((ref, search) async {
  return ref.read(adminRepositoryProvider).fetchAllRentals(search: search);
});
