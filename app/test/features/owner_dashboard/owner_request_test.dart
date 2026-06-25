import 'package:flutter_test/flutter_test.dart';

import 'package:andaloes/features/owner_dashboard/domain/entities/owner_request.dart';
import 'package:andaloes/features/owner_dashboard/data/models/owner_request_model.dart';

// ── Fixture ───────────────────────────────────────────────────────────────────

Map<String, dynamic> _ownerRequestMap({
  String id = 'or-1',
  String generatorId = 'gen-1',
  String companyId = 'comp-1',
  String customerId = 'cust-1',
  String status = 'pending',
  String startDate = '2026-08-01',
  String endDate = '2026-08-07',
  int totalDays = 7,
  double priceTotal = 2100.0,
  double depositAmount = 0,
  String? deliveryAddress,
  String? deliveryTime,
  String? note,
  String createdAt = '2026-07-20T09:00:00.000Z',
}) =>
    {
      'id': id,
      'generator_id': generatorId,
      'company_id': companyId,
      'customer_id': customerId,
      'status': status,
      'start_date': startDate,
      'end_date': endDate,
      'total_days': totalDays,
      'price_total': priceTotal,
      'deposit_amount': depositAmount,
      if (deliveryAddress != null) 'delivery_address': deliveryAddress,
      if (deliveryTime != null) 'delivery_time': deliveryTime,
      if (note != null) 'note': note,
      'created_at': createdAt,
    };

void main() {
  // ── OwnerRequest.fromMap – required fields ─────────────────────────────────

  group('OwnerRequest.fromMap – required fields', () {
    test('id maps from "id"', () {
      expect(OwnerRequest.fromMap(_ownerRequestMap()).id, 'or-1');
    });

    test('generatorId maps from "generator_id"', () {
      expect(OwnerRequest.fromMap(_ownerRequestMap()).generatorId, 'gen-1');
    });

    test('companyId maps from "company_id"', () {
      expect(OwnerRequest.fromMap(_ownerRequestMap()).companyId, 'comp-1');
    });

    test('customerId maps from "customer_id"', () {
      expect(OwnerRequest.fromMap(_ownerRequestMap()).customerId, 'cust-1');
    });

    test('status maps as "pending"', () {
      expect(OwnerRequest.fromMap(_ownerRequestMap()).status, 'pending');
    });

    test('startDate maps correctly', () {
      expect(OwnerRequest.fromMap(_ownerRequestMap()).startDate, '2026-08-01');
    });

    test('endDate maps correctly', () {
      expect(OwnerRequest.fromMap(_ownerRequestMap()).endDate, '2026-08-07');
    });

    test('totalDays maps as int', () {
      expect(OwnerRequest.fromMap(_ownerRequestMap()).totalDays, 7);
    });

    test('priceTotal maps as double', () {
      expect(OwnerRequest.fromMap(_ownerRequestMap()).priceTotal, 2100.0);
    });

    test('depositAmount defaults to 0 when absent', () {
      final m = _ownerRequestMap();
      m.remove('deposit_amount');
      expect(OwnerRequest.fromMap(m).depositAmount, 0.0);
    });

    test('depositAmount maps when present', () {
      expect(
        OwnerRequest.fromMap(_ownerRequestMap(depositAmount: 500.0)).depositAmount,
        500.0,
      );
    });

    test('createdAt parsed from ISO string', () {
      final r = OwnerRequest.fromMap(_ownerRequestMap());
      expect(r.createdAt, DateTime.utc(2026, 7, 20, 9, 0, 0));
    });
  });

  // ── OwnerRequest status convenience getters ───────────────────────────────

  group('OwnerRequest status getters', () {
    test('isPending true for "pending" status', () {
      expect(OwnerRequest.fromMap(_ownerRequestMap(status: 'pending')).isPending, true);
    });

    test('isPending false for other statuses', () {
      expect(OwnerRequest.fromMap(_ownerRequestMap(status: 'accepted')).isPending, false);
      expect(OwnerRequest.fromMap(_ownerRequestMap(status: 'active')).isPending, false);
    });

    test('isActive true for "active" status', () {
      expect(OwnerRequest.fromMap(_ownerRequestMap(status: 'active')).isActive, true);
    });

    test('isActive false for other statuses', () {
      expect(OwnerRequest.fromMap(_ownerRequestMap(status: 'pending')).isActive, false);
      expect(OwnerRequest.fromMap(_ownerRequestMap(status: 'completed')).isActive, false);
    });

    test('isCompleted true for "completed" status', () {
      expect(
        OwnerRequest.fromMap(_ownerRequestMap(status: 'completed')).isCompleted,
        true,
      );
    });

    test('isCompleted false for non-completed statuses', () {
      expect(OwnerRequest.fromMap(_ownerRequestMap(status: 'active')).isCompleted, false);
    });
  });

  // ── OwnerRequest optional fields ──────────────────────────────────────────

  group('OwnerRequest.fromMap – optional fields', () {
    test('note is null when absent', () {
      expect(OwnerRequest.fromMap(_ownerRequestMap()).note, isNull);
    });

    test('note maps when present', () {
      expect(
        OwnerRequest.fromMap(_ownerRequestMap(note: 'Urgent delivery')).note,
        'Urgent delivery',
      );
    });

    test('deliveryAddress is null when absent', () {
      expect(OwnerRequest.fromMap(_ownerRequestMap()).deliveryAddress, isNull);
    });

    test('deliveryAddress maps when present', () {
      expect(
        OwnerRequest.fromMap(_ownerRequestMap(deliveryAddress: '5 Tahrir Sq')).deliveryAddress,
        '5 Tahrir Sq',
      );
    });

    test('deliveryTime is null when absent', () {
      expect(OwnerRequest.fromMap(_ownerRequestMap()).deliveryTime, isNull);
    });

    test('deliveryTime maps when present', () {
      expect(
        OwnerRequest.fromMap(_ownerRequestMap(deliveryTime: '07:00')).deliveryTime,
        '07:00',
      );
    });
  });

  // ── OwnerRequest null/missing field defaults ──────────────────────────────

  group('OwnerRequest.fromMap – missing field defaults', () {
    test('null total_days defaults to 1', () {
      final m = _ownerRequestMap();
      m['total_days'] = null;
      expect(OwnerRequest.fromMap(m).totalDays, 1);
    });

    test('null price_total defaults to 0', () {
      final m = _ownerRequestMap();
      m['price_total'] = null;
      expect(OwnerRequest.fromMap(m).priceTotal, 0.0);
    });

    test('null status defaults to "pending"', () {
      final m = _ownerRequestMap();
      m['status'] = null;
      expect(OwnerRequest.fromMap(m).status, 'pending');
    });
  });

  // ── OwnerRequestModel.fromMap ─────────────────────────────────────────────

  group('OwnerRequestModel.fromMap', () {
    test('is an OwnerRequest subtype', () {
      expect(OwnerRequestModel.fromMap(_ownerRequestMap()), isA<OwnerRequest>());
    });

    test('toMap includes all standard fields', () {
      final model = OwnerRequestModel.fromMap(_ownerRequestMap());
      final map = model.toMap();
      expect(map['id'], 'or-1');
      expect(map['generator_id'], 'gen-1');
      expect(map['status'], 'pending');
      expect(map['total_days'], 7);
      expect(map['price_total'], 2100.0);
      expect(map['deposit_amount'], 0.0);
    });

    test('toMap omits null note', () {
      final map = OwnerRequestModel.fromMap(_ownerRequestMap()).toMap();
      expect(map.containsKey('note'), false);
    });

    test('toMap includes note when set', () {
      final map = OwnerRequestModel.fromMap(
        _ownerRequestMap(note: 'handle with care'),
      ).toMap();
      expect(map['note'], 'handle with care');
    });

    test('round-trip preserves all required fields', () {
      final original = OwnerRequestModel.fromMap(_ownerRequestMap());
      final restored = OwnerRequestModel.fromMap(original.toMap());
      expect(restored.id, original.id);
      expect(restored.status, original.status);
      expect(restored.totalDays, original.totalDays);
      expect(restored.priceTotal, original.priceTotal);
    });
  });
}
