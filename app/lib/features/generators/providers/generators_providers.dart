import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase.dart';
import '../data/generator_repository.dart';

export '../data/generator_repository.dart' show generatorRepositoryProvider;

final generatorsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.read(generatorRepositoryProvider).fetchAll();
});

final remoteFavoritesProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return {};
  return ref.read(generatorRepositoryProvider).fetchFavorites(uid);
});

final favoritesProvider = StateProvider<Set<String>>((ref) => const {});

final showFavoritesOnlyProvider = StateProvider<bool>((ref) => false);

final recentSearchesProvider =
    StateProvider<List<String>>((ref) => const []);

final featuredGeneratorsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.read(generatorRepositoryProvider).fetchFeatured();
});

final recentlyViewedProvider =
    StateProvider<List<Map<String, dynamic>>>((_) => const []);

final newArrivalsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.read(generatorRepositoryProvider).fetchNewArrivals();
});

final autocompleteProvider =
    FutureProvider.autoDispose.family<List<String>, String>((ref, q) async {
  return ref.read(generatorRepositoryProvider).searchAutocomplete(q);
});

// Flash deals: generators whose price_per_day is ≤70% of the average for their
// KVA tier (grouped into <10, 10-50, 50-200, 200+ KVA buckets).
final flashDealsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final data = await supabase
      .from('generators')
      .select(
          'id, title, capacity_kva, price_per_day, city, governorate, photos, avg_score, rating_count, fuel_type, created_at, companies(name)')
      .eq('status', 'available')
      .order('price_per_day', ascending: true)
      .limit(80);
  final all = (data as List).cast<Map<String, dynamic>>();
  // Compute average price per KVA bucket
  int _bucket(num kva) {
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
    final b = _bucket(kva);
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
    final avg = bucketAvg[_bucket(kva)];
    if (avg == null || avg == 0) return false;
    return price <= avg * 0.70;
  }).take(8).toList();
});

// Fetches generators in the same governorate as the user's most recent rental.
// Returns null governorate if user has no rentals (section hidden).
final nearMeProvider =
    FutureProvider.autoDispose<({String? governorate, List<Map<String, dynamic>> generators})>(
        (ref) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return (governorate: null, generators: <Map<String, dynamic>>[]);
  final recent = await supabase
      .from('rental_requests')
      .select('generators(governorate)')
      .eq('customer_id', uid)
      .order('created_at', ascending: false)
      .limit(1);
  final gov = (recent as List).isNotEmpty
      ? ((recent.first['generators'] as Map?)?['governorate']?.toString())
      : null;
  if (gov == null) return (governorate: null, generators: <Map<String, dynamic>>[]);
  final data = await supabase
      .from('generators')
      .select(
          'id, title, capacity_kva, price_per_day, city, governorate, photos, avg_score, rating_count, fuel_type, created_at, companies(name)')
      .eq('status', 'available')
      .eq('governorate', gov)
      .order('avg_score', ascending: false)
      .limit(6);
  return (
    governorate: gov,
    generators: (data as List).cast<Map<String, dynamic>>()
  );
});
