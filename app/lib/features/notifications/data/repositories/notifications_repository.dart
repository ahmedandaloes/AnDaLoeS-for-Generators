import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase.dart';
import '../../domain/repositories/i_notifications_repository.dart';

final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((_) => NotificationsRepository());

class NotificationsRepository implements INotificationsRepository {
  @override
  Future<List<Map<String, dynamic>>> fetch({int limit = 50}) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return [];
    final data = await supabase
        .from('notifications')
        .select('*')
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(limit);
    return (data as List).cast<Map<String, dynamic>>();
  }

  @override
  Future<int> unreadCount() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return 0;
    final data = await supabase
        .from('notifications')
        .select('id')
        .eq('user_id', uid)
        .eq('is_read', false);
    return (data as List).length;
  }

  @override
  Future<void> markRead(String id) async {
    await supabase
        .from('notifications')
        .update({'is_read': true}).eq('id', id);
  }

  @override
  Future<void> markAllRead() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    await supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', uid)
        .eq('is_read', false);
  }

  @override
  Future<void> delete(String id) async {
    await supabase.from('notifications').delete().eq('id', id);
  }
}
