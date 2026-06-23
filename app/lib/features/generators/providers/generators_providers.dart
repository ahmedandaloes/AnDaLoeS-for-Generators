import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase.dart';

// Full list of available generators fetched from Supabase.
final generatorsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final data = await supabase
      .from('generators')
      .select(
          'id, title, capacity_kva, price_per_day, city, governorate, photos, avg_score, rating_count, fuel_type')
      .eq('status', 'available')
      .order('created_at', ascending: false);
  return (data as List).cast<Map<String, dynamic>>();
});

// Current user's saved generator IDs from Supabase.
final remoteFavoritesProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return {};
  final data = await supabase
      .from('user_favorites')
      .select('generator_id')
      .eq('user_id', uid);
  return {for (final r in (data as List)) r['generator_id'].toString()};
});

// In-session saved/favourite generator IDs — seeded from remoteFavoritesProvider on first load.
final favoritesProvider = StateProvider<Set<String>>((ref) => const {});

// When true, the generator list shows only saved generators.
final showFavoritesOnlyProvider = StateProvider<bool>((ref) => false);

// Tracks recent non-empty search terms within the current session (max 5).
final recentSearchesProvider =
    StateProvider<List<String>>((ref) => const []);

// Top-rated generators for the Featured carousel on home screen.
final featuredGeneratorsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final data = await supabase
      .from('generators')
      .select(
          'id, title, capacity_kva, price_per_day, city, governorate, photos, avg_score, rating_count, fuel_type')
      .eq('status', 'available')
      .gte('avg_score', 4.0)
      .order('avg_score', ascending: false)
      .limit(8);
  return (data as List).cast<Map<String, dynamic>>();
});

// Autocomplete suggestions based on partial query (min 2 chars).
final autocompleteProvider =
    FutureProvider.autoDispose.family<List<String>, String>((ref, q) async {
  if (q.length < 2) return [];
  final data = await supabase
      .from('generators')
      .select('title, city, governorate')
      .or('title.ilike.%$q%,city.ilike.%$q%')
      .eq('status', 'available')
      .limit(8);
  final suggestions = <String>{};
  for (final g in (data as List)) {
    final title = g['title']?.toString() ?? '';
    final city = g['city']?.toString() ?? '';
    if (title.toLowerCase().contains(q.toLowerCase())) suggestions.add(title);
    if (city.toLowerCase().contains(q.toLowerCase())) suggestions.add(city);
  }
  return suggestions.take(6).toList();
});
