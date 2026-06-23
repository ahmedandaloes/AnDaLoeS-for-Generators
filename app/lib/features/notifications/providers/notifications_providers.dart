import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase.dart';

final notificationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return [];
  final data = await supabase
      .from('notifications')
      .select('*')
      .eq('user_id', uid)
      .order('created_at', ascending: false)
      .limit(50);
  return (data as List).cast<Map<String, dynamic>>();
});

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return 0;
  final data = await supabase
      .from('notifications')
      .select('id')
      .eq('user_id', uid)
      .eq('is_read', false);
  return (data as List).length;
});
