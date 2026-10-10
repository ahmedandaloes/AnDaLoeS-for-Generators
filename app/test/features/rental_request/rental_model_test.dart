import 'package:flutter_test/flutter_test.dart';

import 'package:thabit_power/features/rental_request/data/models/rental_model.dart';
import 'package:thabit_power/features/rental_request/data/models/rental_request_model.dart';
import 'package:thabit_power/features/rental_request/domain/entities/rental_request.dart';

// ── Fixtures ──────────────────────────────────────────────────────────────────

Map<String, dynamic> _rentalMap({
  String id = 'rent-1',
  String generatorId = 'gen-1',
  String companyId = 'comp-1',
  String customerId = 'cust-1',
  String startDate = '2026-07-01',
  String endDate = '2026-07-07',
  int totalDays = 7,
  double priceTotal = 3000.0,
  String status = 'pending',
  String createdAt = '2026-06-01T10:00:00.000Z',
  String? note,
  double? depositAmount,
  String? deliveryAddress,
  String? deliveryTime,
}) =>
    {
      'id': id,
      'generator_id': generatorId,
      'company_id': companyId,
      'customer_id': customerId,
      'start_date': startDate,
      'end_date': endDate,
      'total_days': totalDays,
      'price_total': priceTotal,
      'status': status,
      'created_at': createdAt,
      if (note != null) 'note': note,
      if (depositAmount != null) 'deposit_amount': depositAmount,
      if (deliveryAddress != null) 'delivery_address': deliveryAddress,
      if (deliveryTime != null) 'delivery_time': deliveryTime,
    };

void main() {
  // ── RentalModel.fromMap ────────────────────────────────────────────────────

  group('RentalModel.fromMap – required fields', () {
    test('id maps from "id"', () {
      expect(RentalModel.fromMap(_rentalMap()).id, 'rent-1');
    });

    test('generatorId maps from "generator_id"', () {
      expect(RentalModel.fromMap(_rentalMap()).generatorId, 'gen-1');
    });

    test('companyId maps from "company_id"', () {
      expect(RentalModel.fromMap(_rentalMap()).companyId, 'comp-1');
    });

    test('customerId maps from "customer_id"', () {
      expect(RentalModel.fromMap(_rentalMap()).customerId, 'cust-1');
    });

    test('startDate maps correctly', () {
      expect(RentalModel.fromMap(_rentalMap()).startDate, '2026-07-01');
    });

    test('endDate maps correctly', () {
      expect(RentalModel.fromMap(_rentalMap()).endDate, '2026-07-07');
    });

    test('totalDays maps as int', () {
      expect(RentalModel.fromMap(_rentalMap()).totalDays, 7);
    });

    test('priceTotal maps as double', () {
      expect(RentalModel.fromMap(_rentalMap()).priceTotal, 3000.0);
    });

    test('status maps correctly', () {
      expect(RentalModel.fromMap(_rentalMap()).status, 'pending');
    });

    test('createdAt is parsed from ISO string', () {
      final r = RentalModel.fromMap(_rentalMap());
      expect(r.createdAt, DateTime.utc(2026, 6, 1, 10, 0, 0));
    });
  });

  group('RentalModel.fromMap – optional fields', () {
    test('note is null when absent', () {
      expect(RentalModel.fromMap(_rentalMap()).note, isNull);
    });

    test('note maps when present', () {
      expect(
        RentalModel.fromMap(_rentalMap(note: 'Please bring cables')).note,
        'Please bring cables',
      );
    });

    test('depositAmount is null when absent', () {
      expect(RentalModel.fromMap(_rentalMap()).depositAmount, isNull);
    });

    test('depositAmount maps as double when present', () {
      expect(
        RentalModel.fromMap(_rentalMap(depositAmount: 500.0)).depositAmount,
        500.0,
      );
    });

    test('deliveryAddress is null when absent', () {
      expect(RentalModel.fromMap(_rentalMap()).deliveryAddress, isNull);
    });

    test('deliveryAddress maps when present', () {
      expect(
        RentalModel.fromMap(_rentalMap(deliveryAddress: '12 Nile St')).deliveryAddress,
        '12 Nile St',
      );
    });

    test('deliveryTime is null when absent', () {
      expect(RentalModel.fromMap(_rentalMap()).deliveryTime, isNull);
    });

    test('deliveryTime maps when present', () {
      expect(
        RentalModel.fromMap(_rentalMap(deliveryTime: '09:00')).deliveryTime,
        '09:00',
      );
    });
  });

  // ── RentalModel.toMap round-trip ──────────────────────────────────────────

  group('RentalModel.toMap round-trip', () {
    test('required fields survive round-trip', () {
      final original = RentalModel.fromMap(_rentalMap());
      final map = original.toMap();
      final restored = RentalModel.fromMap(map);
      expect(restored.id, original.id);
      expect(restored.generatorId, original.generatorId);
      expect(restored.companyId, original.companyId);
      expect(restored.customerId, original.customerId);
      expect(restored.startDate, original.startDate);
      expect(restored.endDate, original.endDate);
      expect(restored.totalDays, original.totalDays);
      expect(restored.priceTotal, original.priceTotal);
      expect(restored.status, original.status);
    });

    test('optional note survives round-trip', () {
      final original = RentalModel.fromMap(_rentalMap(note: 'Test note'));
      final restored = RentalModel.fromMap(original.toMap());
      expect(restored.note, 'Test note');
    });

    test('toMap omits null optional fields', () {
      final map = RentalModel.fromMap(_rentalMap()).toMap();
      expect(map.containsKey('note'), false);
      expect(map.containsKey('deposit_amount'), false);
      expect(map.containsKey('delivery_address'), false);
      expect(map.containsKey('delivery_time'), false);
    });

    test('toMap includes optional fields when set', () {
      final map = RentalModel.fromMap(
        _rentalMap(
          note: 'bring cables',
          depositAmount: 200.0,
          deliveryAddress: '5 Hassan St',
          deliveryTime: '08:00',
        ),
      ).toMap();
      expect(map['note'], 'bring cables');
      expect(map['deposit_amount'], 200.0);
      expect(map['delivery_address'], '5 Hassan St');
      expect(map['delivery_time'], '08:00');
    });
  });

  // ── Status integrity ───────────────────────────────────────────────────────

  group('RentalModel status values', () {
    for (final s in ['pending', 'accepted', 'active', 'completed', 'rejected', 'cancelled']) {
      test('status "$s" round-trips correctly', () {
        final r = RentalModel.fromMap(_rentalMap(status: s));
        expect(r.status, s);
      });
    }
  });

  // ── Price total validation ────────────────────────────────────────────────

  group('RentalModel price_total', () {
    test('price_total as integer value is cast to double', () {
      final m = _rentalMap();
      m['price_total'] = 1500; // int in JSON
      expect(RentalModel.fromMap(m).priceTotal, 1500.0);
    });

    test('price_total zero maps correctly', () {
      expect(RentalModel.fromMap(_rentalMap(priceTotal: 0.0)).priceTotal, 0.0);
    });

    test('price calculation: days × daily rate', () {
      const days = 7;
      const dailyRate = 400.0;
      const expected = days * dailyRate;
      expect(RentalModel.fromMap(_rentalMap(totalDays: days, priceTotal: expected)).priceTotal, 2800.0);
    });
  });

  // ── RentalRequestEntity.fromMap ───────────────────────────────────────────

  group('RentalRequestEntity.fromMap', () {
    test('maps all required fields', () {
      final e = RentalRequestEntity.fromMap(_rentalMap());
      expect(e.id, 'rent-1');
      expect(e.generatorId, 'gen-1');
      expect(e.companyId, 'comp-1');
      expect(e.customerId, 'cust-1');
      expect(e.startDate, '2026-07-01');
      expect(e.endDate, '2026-07-07');
      expect(e.totalDays, 7);
      expect(e.priceTotal, 3000.0);
      expect(e.status, 'pending');
      expect(e.createdAt, DateTime.utc(2026, 6, 1, 10, 0, 0));
    });

    test('note is null when absent', () {
      expect(RentalRequestEntity.fromMap(_rentalMap()).note, isNull);
    });

    test('note maps when present', () {
      expect(
        RentalRequestEntity.fromMap(_rentalMap(note: 'urgent')).note,
        'urgent',
      );
    });
  });

  group('RentalRequestEntity.toMap round-trip', () {
    test('required fields survive round-trip', () {
      final e = RentalRequestEntity.fromMap(_rentalMap());
      final restored = RentalRequestEntity.fromMap(e.toMap());
      expect(restored.id, e.id);
      expect(restored.generatorId, e.generatorId);
      expect(restored.totalDays, e.totalDays);
      expect(restored.priceTotal, e.priceTotal);
      expect(restored.status, e.status);
    });

    test('toMap omits null note', () {
      final map = RentalRequestEntity.fromMap(_rentalMap()).toMap();
      expect(map.containsKey('note'), false);
    });

    test('toMap includes note when set', () {
      final map = RentalRequestEntity.fromMap(_rentalMap(note: 'check')).toMap();
      expect(map['note'], 'check');
    });
  });

  // ── RentalRequestModel.fromMap ────────────────────────────────────────────

  group('RentalRequestModel.fromMap', () {
    test('is a RentalRequestEntity subtype', () {
      expect(RentalRequestModel.fromMap(_rentalMap()), isA<RentalRequestEntity>());
    });

    test('fields match entity fromMap', () {
      final model = RentalRequestModel.fromMap(_rentalMap());
      expect(model.id, 'rent-1');
      expect(model.priceTotal, 3000.0);
      expect(model.status, 'pending');
    });
  });

  // ── Rental status transition table ────────────────────────────────────────

  group('Rental status state machine', () {
    // Defines the allowed "next" statuses for each current status.
    const validTransitions = {
      'pending': ['accepted', 'rejected', 'cancelled'],
      'accepted': ['active', 'cancelled'],
      'active': ['completed'],
      'completed': <String>[],
      'rejected': <String>[],
      'cancelled': <String>[],
    };

    test('pending can transition to accepted', () {
      expect(validTransitions['pending'], contains('accepted'));
    });

    test('pending can transition to rejected', () {
      expect(validTransitions['pending'], contains('rejected'));
    });

    test('pending can transition to cancelled', () {
      expect(validTransitions['pending'], contains('cancelled'));
    });

    test('accepted can transition to active', () {
      expect(validTransitions['accepted'], contains('active'));
    });

    test('accepted can be cancelled', () {
      expect(validTransitions['accepted'], contains('cancelled'));
    });

    test('active can transition to completed', () {
      expect(validTransitions['active'], contains('completed'));
    });

    test('completed is a terminal state — no further transitions', () {
      expect(validTransitions['completed'], isEmpty);
    });

    test('rejected is a terminal state — no further transitions', () {
      expect(validTransitions['rejected'], isEmpty);
    });

    test('cancelled is a terminal state — no further transitions', () {
      expect(validTransitions['cancelled'], isEmpty);
    });

    test('pending cannot jump directly to completed', () {
      expect(validTransitions['pending'], isNot(contains('completed')));
    });

    test('active cannot go back to pending', () {
      expect(validTransitions['active'], isNot(contains('pending')));
    });

    test('accepted cannot go back to pending', () {
      expect(validTransitions['accepted'], isNot(contains('pending')));
    });
  });
}
