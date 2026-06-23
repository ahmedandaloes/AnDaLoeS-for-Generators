import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase.dart';

/// Returns unread message count for a rental request —
/// messages sent by the *other* party that arrived after the last message
/// sent by the current user (or all messages if the user never sent one).
final unreadMessagesProvider =
    FutureProvider.autoDispose.family<int, String>((ref, rentalRequestId) async {
  final uid = supabase.auth.currentUser?.id;
  if (uid == null) return 0;

  // Find timestamp of the current user's most recent message in this thread
  final myLastMsg = await supabase
      .from('messages')
      .select('created_at')
      .eq('rental_request_id', rentalRequestId)
      .eq('sender_id', uid)
      .order('created_at', ascending: false)
      .limit(1)
      .maybeSingle();

  final afterTs = myLastMsg?['created_at']?.toString();

  // Count messages from others since then (fetch IDs and count client-side)
  var query = supabase
      .from('messages')
      .select('id')
      .eq('rental_request_id', rentalRequestId)
      .neq('sender_id', uid);

  if (afterTs != null) {
    query = query.gt('created_at', afterTs);
  }

  final res = await query;
  return (res as List).length;
});
