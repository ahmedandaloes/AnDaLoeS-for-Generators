import '../../domain/entities/notification.dart';

class NotificationModel extends NotificationEntity {
  const NotificationModel({
    required super.id,
    required super.userId,
    required super.type,
    required super.title,
    required super.body,
    required super.isRead,
    super.rentalRequestId,
    required super.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) =>
      NotificationModel(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        type: (map['type'] as String?) ?? '',
        title: (map['title'] as String?) ?? '',
        body: (map['body'] as String?) ?? '',
        isRead: (map['is_read'] as bool?) ?? false,
        rentalRequestId: map['rental_request_id'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
