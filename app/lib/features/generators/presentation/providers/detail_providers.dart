import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/repositories/auth_repository.dart';
import '../../data/repositories/generator_repository.dart';

final generatorDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
        (ref, id) async {
  return ref.read(generatorRepositoryProvider).fetchById(id);
});

final bookedDatesProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, generatorId) async {
  return ref.read(generatorRepositoryProvider).fetchBooked(generatorId);
});

final generatorReviewsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, generatorId) async {
  return ref.read(generatorRepositoryProvider).fetchReviews(generatorId);
});

final avgResponseTimeProvider =
    FutureProvider.autoDispose.family<int?, String>((ref, companyId) async {
  return ref
      .read(generatorRepositoryProvider)
      .fetchAvgResponseTime(companyId);
});

// Percentage of requests the owner accepted (0–100), null if no data.
final ownerAcceptanceRateProvider =
    FutureProvider.autoDispose.family<int?, String>((ref, companyId) async {
  return ref
      .read(generatorRepositoryProvider)
      .fetchOwnerAcceptanceRate(companyId);
});

final isFavProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, id) async {
  final uid = ref.read(authRepositoryProvider).currentUserId;
  if (uid == null) return false;
  return ref.read(generatorRepositoryProvider).fetchIsFav(uid, id);
});

// Weighted average rating across all generators in a company.
final companyAvgRatingProvider = FutureProvider.autoDispose
    .family<({double avg, int total}), String>((ref, companyId) async {
  return ref
      .read(generatorRepositoryProvider)
      .fetchCompanyAvgRating(companyId);
});

final similarGeneratorsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, Map<String, dynamic>>(
        (ref, gen) async {
  return ref.read(generatorRepositoryProvider).fetchSimilar(gen);
});
