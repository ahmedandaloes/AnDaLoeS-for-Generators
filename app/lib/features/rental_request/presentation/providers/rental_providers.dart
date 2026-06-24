import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/rental_repository.dart';

export '../../data/repositories/rental_repository.dart'
    show rentalRepositoryProvider;

final myRentalsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.read(rentalRepositoryProvider);
  final uid = repo.currentUserId;
  if (uid == null) return [];
  return repo.fetchMyRentals(uid);
});
