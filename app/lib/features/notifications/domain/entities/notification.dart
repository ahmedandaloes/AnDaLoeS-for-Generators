class NotificationEntity {
  const NotificationEntity({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    this.rentalRequestId,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final String? rentalRequestId;
  final DateTime createdAt;

  factory NotificationEntity.fromMap(Map<String, dynamic> map) =>
      NotificationEntity(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        type: map['type'] as String,
        title: map['title'] as String,
        body: map['body'] as String,
        isRead: map['is_read'] as bool,
        rentalRequestId: map['rental_request_id'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'type': type,
        'title': title,
        'body': body,
        'is_read': isRead,
        if (rentalRequestId != null) 'rental_request_id': rentalRequestId,
        'created_at': createdAt.toIso8601String(),
      };
}
