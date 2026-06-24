import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/notifications_repository.dart';

final notificationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>(
        (ref) => ref.read(notificationsRepositoryProvider).fetch());

final unreadCountProvider = FutureProvider.autoDispose<int>(
    (ref) => ref.read(notificationsRepositoryProvider).unreadCount());
