import '../entities/message.dart';

abstract interface class IMessageRepository {
  Future<List<MessageEntity>> fetchMessages(String rentalRequestId);
  Future<void> sendMessage({
    required String rentalRequestId,
    required String senderId,
    required String text,
  });
  Future<int> unreadCount(String rentalRequestId, String currentUserId);
}
