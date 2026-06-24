import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/repositories/auth_repository.dart';
import '../../data/repositories/generator_repository.dart';
import '../widgets/generator_filter.dart';

final savedSearchesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final authRepo = ref.read(authRepositoryProvider);
  final uid = authRepo.currentUserId;
  if (uid == null || authRepo.isCurrentUserAnonymous) return [];
  return ref.read(generatorRepositoryProvider).fetchSavedSearches(uid);
});

Future<void> saveSearch({
  required WidgetRef ref,
  required String name,
  required GeneratorFilter filter,
}) async {
  final uid = ref.read(authRepositoryProvider).currentUserId;
  if (uid == null) return;
  await ref.read(generatorRepositoryProvider).saveSearch(uid, {
    'name': name,
    'filter': filter.toJson(),
  });
}

Future<void> deleteSavedSearch(WidgetRef ref, String id) async {
  await ref.read(generatorRepositoryProvider).deleteSavedSearch(id);
}
