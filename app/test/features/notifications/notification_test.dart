import 'package:flutter_test/flutter_test.dart';

import 'package:thabit_power/features/notifications/domain/entities/notification.dart';
import 'package:thabit_power/features/notifications/data/models/notification_model.dart';

// ── Fixture ───────────────────────────────────────────────────────────────────

Map<String, dynamic> _notifMap({
  String id = 'notif-1',
  String userId = 'user-1',
  String type = 'rental_accepted',
  String title = 'Request Accepted',
  String body = 'Your rental request was accepted.',
  bool isRead = false,
  String? rentalRequestId,
  String createdAt = '2026-06-15T08:00:00.000Z',
}) =>
    {
      'id': id,
      'user_id': userId,
      'type': type,
      'title': title,
      'body': body,
      'is_read': isRead,
      if (rentalRequestId != null) 'rental_request_id': rentalRequestId,
      'created_at': createdAt,
    };

void main() {
  // ── NotificationEntity.fromMap ────────────────────────────────────────────

  group('NotificationEntity.fromMap – required fields', () {
    test('id maps from "id"', () {
      expect(NotificationEntity.fromMap(_notifMap()).id, 'notif-1');
    });

    test('userId maps from "user_id"', () {
      expect(NotificationEntity.fromMap(_notifMap()).userId, 'user-1');
    });

    test('type maps correctly', () {
      expect(NotificationEntity.fromMap(_notifMap()).type, 'rental_accepted');
    });

    test('title maps correctly', () {
      expect(NotificationEntity.fromMap(_notifMap()).title, 'Request Accepted');
    });

    test('body maps correctly', () {
      expect(
        NotificationEntity.fromMap(_notifMap()).body,
        'Your rental request was accepted.',
      );
    });

    test('isRead maps as bool false', () {
      expect(NotificationEntity.fromMap(_notifMap()).isRead, false);
    });

    test('isRead maps as bool true', () {
      expect(NotificationEntity.fromMap(_notifMap(isRead: true)).isRead, true);
    });

    test('createdAt parses ISO string', () {
      final n = NotificationEntity.fromMap(_notifMap());
      expect(n.createdAt, DateTime.utc(2026, 6, 15, 8, 0, 0));
    });
  });

  group('NotificationEntity.fromMap – optional rentalRequestId', () {
    test('rentalRequestId is null when absent', () {
      expect(NotificationEntity.fromMap(_notifMap()).rentalRequestId, isNull);
    });

    test('rentalRequestId maps when present', () {
      expect(
        NotificationEntity.fromMap(
          _notifMap(rentalRequestId: 'rent-42'),
        ).rentalRequestId,
        'rent-42',
      );
    });
  });

  // ── NotificationEntity.toMap round-trip ──────────────────────────────────

  group('NotificationEntity.toMap round-trip', () {
    test('required fields survive round-trip', () {
      final n = NotificationEntity.fromMap(_notifMap());
      final map = n.toMap();
      expect(map['id'], 'notif-1');
      expect(map['user_id'], 'user-1');
      expect(map['type'], 'rental_accepted');
      expect(map['title'], 'Request Accepted');
      expect(map['body'], 'Your rental request was accepted.');
      expect(map['is_read'], false);
    });

    test('toMap omits rentalRequestId when null', () {
      final map = NotificationEntity.fromMap(_notifMap()).toMap();
      expect(map.containsKey('rental_request_id'), false);
    });

    test('toMap includes rentalRequestId when set', () {
      final map = NotificationEntity.fromMap(
        _notifMap(rentalRequestId: 'rent-10'),
      ).toMap();
      expect(map['rental_request_id'], 'rent-10');
    });

    test('created_at serialized as ISO string', () {
      final map = NotificationEntity.fromMap(_notifMap()).toMap();
      expect(map['created_at'], isA<String>());
      expect((map['created_at'] as String), contains('2026-06-15'));
    });
  });

  // ── NotificationModel.fromMap ─────────────────────────────────────────────

  group('NotificationModel.fromMap', () {
    test('is a NotificationEntity subtype', () {
      expect(NotificationModel.fromMap(_notifMap()), isA<NotificationEntity>());
    });

    test('handles null type gracefully (defaults to empty string)', () {
      final m = _notifMap();
      m['type'] = null;
      expect(NotificationModel.fromMap(m).type, '');
    });

    test('handles null title gracefully', () {
      final m = _notifMap();
      m['title'] = null;
      expect(NotificationModel.fromMap(m).title, '');
    });

    test('handles null body gracefully', () {
      final m = _notifMap();
      m['body'] = null;
      expect(NotificationModel.fromMap(m).body, '');
    });

    test('handles null is_read gracefully (defaults to false)', () {
      final m = _notifMap();
      m['is_read'] = null;
      expect(NotificationModel.fromMap(m).isRead, false);
    });

    test('fields match entity values', () {
      final model = NotificationModel.fromMap(_notifMap());
      expect(model.id, 'notif-1');
      expect(model.type, 'rental_accepted');
      expect(model.isRead, false);
    });
  });
}
