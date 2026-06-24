import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/repositories/auth_repository.dart';
import '../../data/repositories/generator_repository.dart';

export '../../data/repositories/generator_repository.dart'
    show generatorRepositoryProvider;

final generatorsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.read(generatorRepositoryProvider).fetchAllRaw();
});

final remoteFavoritesProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
  final uid = ref.read(authRepositoryProvider).currentUserId;
  if (uid == null) return {};
  return ref.read(generatorRepositoryProvider).fetchFavorites(uid);
});

final favoritesProvider = StateProvider<Set<String>>((ref) => const {});

final showFavoritesOnlyProvider = StateProvider<bool>((ref) => false);

final recentSearchesProvider =
    StateProvider<List<String>>((ref) => const []);

final featuredGeneratorsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.read(generatorRepositoryProvider).fetchFeaturedRaw();
});

final recentlyViewedProvider =
    StateProvider<List<Map<String, dynamic>>>((_) => const []);

final newArrivalsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.read(generatorRepositoryProvider).fetchNewArrivalsRaw();
});

final autocompleteProvider =
    FutureProvider.autoDispose.family<List<String>, String>((ref, q) async {
  return ref.read(generatorRepositoryProvider).searchAutocomplete(q);
});

// Flash deals: generators whose price_per_day is ≤70% of the average for their
// KVA tier (grouped into <10, 10-50, 50-200, 200+ KVA buckets).
final flashDealsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final all = await ref.read(generatorRepositoryProvider).fetchFlashDeals();
  int bucket(num kva) {
    if (kva < 10) return 0;
    if (kva < 50) return 1;
    if (kva < 200) return 2;
    return 3;
  }

  final bucketTotals = <int, double>{};
  final bucketCounts = <int, int>{};
  for (final g in all) {
    final kva = (g['capacity_kva'] as num?) ?? 0;
    final price = (g['price_per_day'] as num?)?.toDouble() ?? 0;
    final b = bucket(kva);
    bucketTotals[b] = (bucketTotals[b] ?? 0) + price;
    bucketCounts[b] = (bucketCounts[b] ?? 0) + 1;
  }
  final bucketAvg = {
    for (final k in bucketTotals.keys)
      k: bucketTotals[k]! / bucketCounts[k]!,
  };
  return all.where((g) {
    final kva = (g['capacity_kva'] as num?) ?? 0;
    final price = (g['price_per_day'] as num?)?.toDouble() ?? 0;
    final avg = bucketAvg[bucket(kva)];
    if (avg == null || avg == 0) return false;
    return price <= avg * 0.70;
  }).take(8).toList();
});

// Fetches generators in the same governorate as the user's most recent rental.
final nearMeProvider = FutureProvider.autoDispose<
    ({String? governorate, List<Map<String, dynamic>> generators})>((ref) async {
  final uid = ref.read(authRepositoryProvider).currentUserId;
  if (uid == null) {
    return (governorate: null, generators: <Map<String, dynamic>>[]);
  }
  return ref.read(generatorRepositoryProvider).fetchNearMe(uid);
});

// Top rated companies by avg generator rating.
final topRatedOwnersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final companies =
      await ref.read(generatorRepositoryProvider).fetchTopRatedOwners();
  final scored = companies.map((c) {
    final gens = (c['generators'] as List?) ?? [];
    if (gens.length < 2) return null;
    double totalScore = 0;
    int totalRatings = 0;
    for (final g in gens) {
      final sc = (g['avg_score'] as num?)?.toDouble() ?? 0;
      final cnt = (g['rating_count'] as num?)?.toInt() ?? 0;
      totalScore += sc * cnt;
      totalRatings += cnt;
    }
    if (totalRatings < 3) return null;
    final avg = totalScore / totalRatings;
    return {
      ...c,
      '_avg': avg,
      '_ratings': totalRatings,
      '_gen_count': gens.length
    };
  }).whereType<Map<String, dynamic>>().toList()
    ..sort((a, b) => (b['_avg'] as double).compareTo(a['_avg'] as double));
  return scored.take(8).toList();
});

// Shared current user profile — role/name without duplicating the Supabase call.
final currentProfileProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final uid = ref.read(authRepositoryProvider).currentUserId;
  if (uid == null) return null;
  return ref
      .read(generatorRepositoryProvider)
      .fetchCurrentUserProfile(uid);
});
