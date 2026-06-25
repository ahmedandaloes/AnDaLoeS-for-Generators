import 'package:flutter_test/flutter_test.dart';

import 'package:thabit_power/features/chat/domain/entities/message.dart';

// ── Fixture ───────────────────────────────────────────────────────────────────

Map<String, dynamic> _messageMap({
  String id = 'msg-1',
  String rentalRequestId = 'rent-1',
  String senderId = 'user-1',
  String text = 'Hello, when can you deliver?',
  String createdAt = '2026-06-20T14:00:00.000Z',
}) =>
    {
      'id': id,
      'rental_request_id': rentalRequestId,
      'sender_id': senderId,
      'text': text,
      'created_at': createdAt,
    };

void main() {
  // ── MessageEntity.fromMap ─────────────────────────────────────────────────

  group('MessageEntity.fromMap – required fields', () {
    test('id maps from "id"', () {
      expect(MessageEntity.fromMap(_messageMap()).id, 'msg-1');
    });

    test('rentalRequestId maps from "rental_request_id"', () {
      expect(MessageEntity.fromMap(_messageMap()).rentalRequestId, 'rent-1');
    });

    test('senderId maps from "sender_id"', () {
      expect(MessageEntity.fromMap(_messageMap()).senderId, 'user-1');
    });

    test('text maps correctly', () {
      expect(
        MessageEntity.fromMap(_messageMap()).text,
        'Hello, when can you deliver?',
      );
    });

    test('createdAt parses ISO string', () {
      final m = MessageEntity.fromMap(_messageMap());
      expect(m.createdAt, DateTime.utc(2026, 6, 20, 14, 0, 0));
    });
  });

  // ── MessageEntity.toMap round-trip ────────────────────────────────────────

  group('MessageEntity.toMap round-trip', () {
    test('all fields survive round-trip', () {
      final original = MessageEntity.fromMap(_messageMap());
      final map = original.toMap();
      final restored = MessageEntity.fromMap(map);
      expect(restored.id, original.id);
      expect(restored.rentalRequestId, original.rentalRequestId);
      expect(restored.senderId, original.senderId);
      expect(restored.text, original.text);
    });

    test('toMap includes all required keys', () {
      final map = MessageEntity.fromMap(_messageMap()).toMap();
      expect(map.containsKey('id'), true);
      expect(map.containsKey('rental_request_id'), true);
      expect(map.containsKey('sender_id'), true);
      expect(map.containsKey('text'), true);
      expect(map.containsKey('created_at'), true);
    });

    test('created_at serialized as string', () {
      final map = MessageEntity.fromMap(_messageMap()).toMap();
      expect(map['created_at'], isA<String>());
    });
  });

  // ── MessageEntity direct construction ────────────────────────────────────

  group('MessageEntity direct construction', () {
    final m = MessageEntity(
      id: 'm-99',
      rentalRequestId: 'r-1',
      senderId: 'u-99',
      text: 'Ready to deliver!',
      createdAt: DateTime(2026, 7, 1, 10, 30),
    );

    test('id accessible', () => expect(m.id, 'm-99'));
    test('text accessible', () => expect(m.text, 'Ready to deliver!'));
    test('createdAt accessible', () => expect(m.createdAt, DateTime(2026, 7, 1, 10, 30)));
  });

  // ── MessageEntity scenarios ───────────────────────────────────────────────

  group('MessageEntity scenarios', () {
    test('Arabic text preserved correctly', () {
      final m = MessageEntity.fromMap(
        _messageMap(text: 'متى يمكنك التسليم؟'),
      );
      expect(m.text, 'متى يمكنك التسليم؟');
    });

    test('long text preserved correctly', () {
      const longText = 'This is a very long message that describes '
          'all the delivery requirements in great detail, '
          'including the exact time and location.';
      final m = MessageEntity.fromMap(_messageMap(text: longText));
      expect(m.text, longText);
    });

    test('multiple messages from same sender have distinct ids', () {
      final m1 = MessageEntity.fromMap(_messageMap(id: 'msg-1'));
      final m2 = MessageEntity.fromMap(_messageMap(id: 'msg-2'));
      expect(m1.id, isNot(equals(m2.id)));
    });
  });
}
