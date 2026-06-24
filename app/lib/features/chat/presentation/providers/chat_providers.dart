import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/message_repository.dart';

export '../../data/repositories/message_repository.dart'
    show messageRepositoryProvider;

/// Count of unread messages in a rental conversation for the current user.
final unreadMessagesProvider =
    FutureProvider.autoDispose.family<int, String>((ref, rentalId) async {
  final repo = ref.read(messageRepositoryProvider);
  final uid = repo.currentUserId;
  if (uid == null) return 0;
  return repo.unreadCount(rentalId, uid);
});
