import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/i_message_repository.dart';

final messageRepositoryProvider =
    Provider<MessageRepository>((_) => MessageRepository());

class MessageRepository implements IMessageRepository {
  String? get currentUserId => supabase.auth.currentUser?.id;

  @override
  Future<List<MessageEntity>> fetchMessages(String rentalRequestId) async {
    final data = await supabase
        .from('messages')
        .select()
        .eq('rental_request_id', rentalRequestId)
        .order('created_at', ascending: true);
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(MessageEntity.fromMap)
        .toList();
  }

  @override
  Future<void> sendMessage({
    required String rentalRequestId,
    required String senderId,
    required String text,
  }) async {
    await supabase.from('messages').insert({
      'rental_request_id': rentalRequestId,
      'sender_id': senderId,
      'text': text,
    });
  }

  @override
  Future<int> unreadCount(
      String rentalRequestId, String currentUserId) async {
    final myLastMsg = await supabase
        .from('messages')
        .select('created_at')
        .eq('rental_request_id', rentalRequestId)
        .eq('sender_id', currentUserId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    final afterTs = myLastMsg?['created_at']?.toString();

    var query = supabase
        .from('messages')
        .select('id')
        .eq('rental_request_id', rentalRequestId)
        .neq('sender_id', currentUserId);

    if (afterTs != null) {
      query = query.gt('created_at', afterTs);
    }

    final res = await query;
    return (res as List).length;
  }
}
