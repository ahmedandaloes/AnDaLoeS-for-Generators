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
