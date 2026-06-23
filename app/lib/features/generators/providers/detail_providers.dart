import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase.dart';
import '../data/generator_repository.dart';

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

final isFavProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, id) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return false;
  return ref.read(generatorRepositoryProvider).fetchIsFav(uid, id);
});

final similarGeneratorsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, Map<String, dynamic>>(
        (ref, gen) async {
  return ref.read(generatorRepositoryProvider).fetchSimilar(gen);
});
