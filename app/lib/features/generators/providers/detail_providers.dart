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

// Percentage of requests the owner accepted (0–100), null if no data.
final ownerAcceptanceRateProvider =
    FutureProvider.autoDispose.family<int?, String>((ref, companyId) async {
  if (companyId.isEmpty) return null;
  final data = await supabase
      .from('rental_requests')
      .select('status')
      .eq('company_id', companyId)
      .inFilter('status', ['accepted', 'rejected'])
      .limit(100);
  final list = (data as List).cast<Map<String, dynamic>>();
  if (list.isEmpty) return null;
  final accepted = list.where((r) => r['status'] == 'accepted').length;
  return ((accepted / list.length) * 100).round();
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
