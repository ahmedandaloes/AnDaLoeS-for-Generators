import 'package:flutter_test/flutter_test.dart';

import 'package:thabit_power/features/company/domain/entities/company.dart';
import 'package:thabit_power/features/company/data/models/company_model.dart';

// ── Fixture ───────────────────────────────────────────────────────────────────

Map<String, dynamic> _companyMap({
  String id = 'comp-1',
  String ownerId = 'user-1',
  String name = 'Delta Power Co',
  String status = 'pending',
  String? city,
  String? governorate,
  String? description,
  String? verificationStatus,
  String? createdAt,
}) =>
    {
      'id': id,
      'owner_user_id': ownerId,
      'name': name,
      'status': status,
      if (city != null) 'city': city,
      if (governorate != null) 'governorate': governorate,
      if (description != null) 'description': description,
      if (verificationStatus != null) 'verification_status': verificationStatus,
      if (createdAt != null) 'created_at': createdAt,
    };

void main() {
  // ── Company.fromMap – required fields ─────────────────────────────────────

  group('Company.fromMap – required fields', () {
    test('id maps from "id"', () {
      expect(Company.fromMap(_companyMap()).id, 'comp-1');
    });

    test('ownerId maps from "owner_user_id"', () {
      expect(Company.fromMap(_companyMap()).ownerId, 'user-1');
    });

    test('name maps correctly', () {
      expect(Company.fromMap(_companyMap()).name, 'Delta Power Co');
    });

    test('status defaults to pending when absent', () {
      final m = _companyMap();
      m.remove('status');
      expect(Company.fromMap(m).status, 'pending');
    });
  });

  // ── Company.fromMap – status field ────────────────────────────────────────

  group('Company.fromMap – status field', () {
    test('status "pending" maps correctly', () {
      expect(Company.fromMap(_companyMap(status: 'pending')).status, 'pending');
    });

    test('status "approved" maps correctly', () {
      expect(Company.fromMap(_companyMap(status: 'approved')).status, 'approved');
    });

    test('status "rejected" maps correctly', () {
      expect(Company.fromMap(_companyMap(status: 'rejected')).status, 'rejected');
    });
  });

  // ── Company.fromMap – optional fields ────────────────────────────────────

  group('Company.fromMap – optional fields', () {
    test('city is null when absent', () {
      expect(Company.fromMap(_companyMap()).city, isNull);
    });

    test('city maps when present', () {
      expect(Company.fromMap(_companyMap(city: 'Cairo')).city, 'Cairo');
    });

    test('governorate is null when absent', () {
      expect(Company.fromMap(_companyMap()).governorate, isNull);
    });

    test('governorate maps when present', () {
      expect(
        Company.fromMap(_companyMap(governorate: 'القاهرة')).governorate,
        'القاهرة',
      );
    });

    test('description is null when absent', () {
      expect(Company.fromMap(_companyMap()).description, isNull);
    });

    test('description maps when present', () {
      expect(
        Company.fromMap(_companyMap(description: 'We power Egypt')).description,
        'We power Egypt',
      );
    });

    test('verificationStatus is null when absent', () {
      expect(Company.fromMap(_companyMap()).verificationStatus, isNull);
    });

    test('verificationStatus "approved" maps correctly', () {
      expect(
        Company.fromMap(
          _companyMap(verificationStatus: 'approved'),
        ).verificationStatus,
        'approved',
      );
    });

    test('verificationStatus "pending" maps correctly', () {
      expect(
        Company.fromMap(
          _companyMap(verificationStatus: 'pending'),
        ).verificationStatus,
        'pending',
      );
    });

    test('createdAt is null when absent', () {
      expect(Company.fromMap(_companyMap()).createdAt, isNull);
    });

    test('createdAt parses ISO string when present', () {
      final c = Company.fromMap(
        _companyMap(createdAt: '2025-03-15T00:00:00.000Z'),
      );
      expect(c.createdAt, DateTime.utc(2025, 3, 15));
    });

    test('invalid createdAt string yields null', () {
      final m = _companyMap()..['created_at'] = 'bad-date';
      expect(Company.fromMap(m).createdAt, isNull);
    });
  });

  // ── Company.fromMap – null field defaults ─────────────────────────────────

  group('Company.fromMap – null field defaults', () {
    test('null id defaults to empty string', () {
      final m = _companyMap();
      m['id'] = null;
      expect(Company.fromMap(m).id, '');
    });

    test('null name defaults to empty string', () {
      final m = _companyMap();
      m['name'] = null;
      expect(Company.fromMap(m).name, '');
    });

    test('null owner_user_id defaults to empty string', () {
      final m = _companyMap();
      m['owner_user_id'] = null;
      expect(Company.fromMap(m).ownerId, '');
    });

    test('null status defaults to "pending"', () {
      final m = _companyMap();
      m['status'] = null;
      expect(Company.fromMap(m).status, 'pending');
    });
  });

  // ── Company.toMap round-trip ──────────────────────────────────────────────

  group('Company.toMap round-trip', () {
    test('required fields present in toMap', () {
      final map = Company.fromMap(_companyMap()).toMap();
      expect(map['id'], 'comp-1');
      expect(map['owner_user_id'], 'user-1');
      expect(map['name'], 'Delta Power Co');
      expect(map['status'], 'pending');
    });

    test('toMap omits null optional fields', () {
      final map = Company.fromMap(_companyMap()).toMap();
      expect(map.containsKey('city'), false);
      expect(map.containsKey('governorate'), false);
      expect(map.containsKey('description'), false);
    });

    test('toMap includes optional city when set', () {
      final map = Company.fromMap(_companyMap(city: 'Alexandria')).toMap();
      expect(map['city'], 'Alexandria');
    });

    test('fromMap → toMap → fromMap identity on required fields', () {
      final original = Company.fromMap(_companyMap(
        city: 'Giza',
        governorate: 'الجيزة',
        description: 'Power company',
      ));
      final restored = Company.fromMap(original.toMap());
      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.status, original.status);
      expect(restored.city, original.city);
    });
  });

  // ── CompanyModel.fromMap ──────────────────────────────────────────────────

  group('CompanyModel.fromMap', () {
    test('is a Company subtype', () {
      expect(CompanyModel.fromMap(_companyMap()), isA<Company>());
    });

    test('id matches Company.fromMap', () {
      expect(CompanyModel.fromMap(_companyMap()).id, 'comp-1');
    });

    test('status "approved" maps in CompanyModel', () {
      final model = CompanyModel.fromMap(_companyMap(status: 'approved'));
      expect(model.status, 'approved');
    });

    test('verificationStatus maps in CompanyModel', () {
      final model = CompanyModel.fromMap(
        _companyMap(verificationStatus: 'approved'),
      );
      expect(model.verificationStatus, 'approved');
    });
  });
}
