class MessageEntity {
  const MessageEntity({
    required this.id,
    required this.rentalRequestId,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String rentalRequestId;
  final String senderId;
  final String text;
  final DateTime createdAt;

  factory MessageEntity.fromMap(Map<String, dynamic> map) => MessageEntity(
        id: map['id'] as String,
        rentalRequestId: map['rental_request_id'] as String,
        senderId: map['sender_id'] as String,
        text: map['text'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'rental_request_id': rentalRequestId,
        'sender_id': senderId,
        'text': text,
        'created_at': createdAt.toIso8601String(),
      };
}
