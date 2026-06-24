import '../entities/chat_message.dart';

abstract interface class IChatRepository {
  Future<List<ChatMessage>> fetchMessages(String rentalId);
  Future<void> sendMessage(String rentalId, String senderId, String content);
  Stream<List<ChatMessage>> watchMessages(String rentalId);
}
