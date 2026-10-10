import 'package:flutter_test/flutter_test.dart';

import 'package:thabit_power/features/profile/domain/entities/profile.dart';

// ── Fixture ───────────────────────────────────────────────────────────────────

Map<String, dynamic> _profileMap({
  String id = 'user-1',
  String role = 'customer',
  String? fullName,
  String? phone,
  String? avatarUrl,
  String? createdAt,
}) =>
    {
      'id': id,
      'role': role,
      if (fullName != null) 'full_name': fullName,
      if (phone != null) 'phone': phone,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (createdAt != null) 'created_at': createdAt,
    };

void main() {
  // ── Profile.fromMap – required fields ─────────────────────────────────────

  group('Profile.fromMap – required fields', () {
    test('id maps from "id"', () {
      expect(Profile.fromMap(_profileMap()).id, 'user-1');
    });

    test('role maps from "role"', () {
      expect(Profile.fromMap(_profileMap()).role, 'customer');
    });

    test('null id defaults to empty string', () {
      final m = _profileMap();
      m['id'] = null;
      expect(Profile.fromMap(m).id, '');
    });

    test('null role defaults to "customer"', () {
      final m = _profileMap();
      m['role'] = null;
      expect(Profile.fromMap(m).role, 'customer');
    });

    test('missing role key defaults to "customer"', () {
      final m = _profileMap();
      m.remove('role');
      expect(Profile.fromMap(m).role, 'customer');
    });
  });

  // ── Profile.fromMap – role field serialization ────────────────────────────

  group('Profile.fromMap – role field', () {
    test('role "customer" maps correctly', () {
      expect(Profile.fromMap(_profileMap(role: 'customer')).role, 'customer');
    });

    test('role "owner" maps correctly', () {
      expect(Profile.fromMap(_profileMap(role: 'owner')).role, 'owner');
    });

    test('role "admin" maps correctly', () {
      expect(Profile.fromMap(_profileMap(role: 'admin')).role, 'admin');
    });

    test('role "guest" maps correctly', () {
      expect(Profile.fromMap(_profileMap(role: 'guest')).role, 'guest');
    });
  });

  // ── Profile.fromMap – optional fields ─────────────────────────────────────

  group('Profile.fromMap – optional fields', () {
    test('fullName is null when absent', () {
      expect(Profile.fromMap(_profileMap()).fullName, isNull);
    });

    test('fullName maps when present', () {
      expect(
        Profile.fromMap(_profileMap(fullName: 'Ahmed Hassan')).fullName,
        'Ahmed Hassan',
      );
    });

    test('phone is null when absent', () {
      expect(Profile.fromMap(_profileMap()).phone, isNull);
    });

    test('phone maps when present', () {
      expect(
        Profile.fromMap(_profileMap(phone: '01012345678')).phone,
        '01012345678',
      );
    });

    test('avatarUrl is null when absent', () {
      expect(Profile.fromMap(_profileMap()).avatarUrl, isNull);
    });

    test('avatarUrl maps when present', () {
      expect(
        Profile.fromMap(_profileMap(avatarUrl: 'https://cdn.example.com/avatar.jpg')).avatarUrl,
        'https://cdn.example.com/avatar.jpg',
      );
    });

    test('joinedAt is null when absent', () {
      expect(Profile.fromMap(_profileMap()).joinedAt, isNull);
    });

    test('joinedAt parses ISO string when present', () {
      final p = Profile.fromMap(_profileMap(createdAt: '2025-06-01T00:00:00.000Z'));
      expect(p.joinedAt, DateTime.utc(2025, 6, 1));
    });

    test('invalid createdAt string yields null', () {
      final m = _profileMap()..['created_at'] = 'not-a-date';
      expect(Profile.fromMap(m).joinedAt, isNull);
    });
  });

  // ── Profile construction ──────────────────────────────────────────────────

  group('Profile direct construction', () {
    test('all fields accessible via constructor', () {
      const p = Profile(
        id: 'u-99',
        role: 'admin',
        fullName: 'System Admin',
        phone: '0000000000',
        avatarUrl: 'https://example.com/img.png',
      );
      expect(p.id, 'u-99');
      expect(p.role, 'admin');
      expect(p.fullName, 'System Admin');
      expect(p.phone, '0000000000');
      expect(p.avatarUrl, 'https://example.com/img.png');
      expect(p.joinedAt, isNull);
    });

    test('joinedAt available when provided', () {
      final p = Profile(
        id: 'u-1',
        role: 'customer',
        joinedAt: DateTime(2025, 1, 1),
      );
      expect(p.joinedAt, DateTime(2025, 1, 1));
    });
  });
}
