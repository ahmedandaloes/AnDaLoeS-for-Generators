class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.rentalId,
    required this.senderId,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String rentalId;
  final String senderId;
  final String content;
  final DateTime createdAt;

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
        id: map['id'] as String,
        rentalId: map['rental_request_id'] as String,
        senderId: map['sender_id'] as String,
        content: map['content'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
