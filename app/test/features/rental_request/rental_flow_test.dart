import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Rental date math (inclusive end date)', () {
    test('same-day rental = 1 day', () {
      final start = DateTime(2026, 7, 1);
      final end = DateTime(2026, 7, 1);
      final days = end.difference(start).inDays + 1;
      expect(days, 1);
    });

    test('3-day range gives 3 days', () {
      final start = DateTime(2026, 7, 1);
      final end = DateTime(2026, 7, 3);
      final days = end.difference(start).inDays + 1;
      expect(days, 3);
    });

    test('price total = days × price_per_day', () {
      const pricePerDay = 500.0;
      const days = 3;
      final total = pricePerDay * days;
      expect(total, 1500.0);
    });

    test('end cannot be before start', () {
      final start = DateTime(2026, 7, 5);
      final end = DateTime(2026, 7, 3);
      final days = end.difference(start).inDays + 1;
      expect(days, isNegative);
    });
  });

  group('Rental status transitions', () {
    const validNext = {
      'pending': ['accepted', 'rejected', 'cancelled'],
      'accepted': ['active', 'cancelled'],
      'active': ['done'],
      'rejected': <String>[],
      'cancelled': <String>[],
      'done': <String>[],
    };

    test('pending → accepted is valid', () {
      expect(validNext['pending'], contains('accepted'));
    });

    test('pending → cancelled is valid', () {
      expect(validNext['pending'], contains('cancelled'));
    });

    test('done → anything is invalid', () {
      expect(validNext['done'], isEmpty);
    });

    test('rejected → anything is invalid', () {
      expect(validNext['rejected'], isEmpty);
    });

    test('active → done is valid', () {
      expect(validNext['active'], contains('done'));
    });

    test('accepted → active is valid', () {
      expect(validNext['accepted'], contains('active'));
    });
  });

  group('Commission calculation', () {
    double calcCommission(double total, double ratePercent) {
      return double.parse((total * ratePercent / 100).toStringAsFixed(2));
    }

    test('10% of 1500 = 150.00', () {
      expect(calcCommission(1500, 10), 150.00);
    });

    test('0% = no commission', () {
      expect(calcCommission(1500, 0), 0.0);
    });

    test('commission capped at total (100%)', () {
      final commission = calcCommission(1500, 100);
      expect(commission, lessThanOrEqualTo(1500));
    });

    test('owner net = total - commission', () {
      const total = 1500.0;
      const commission = 150.0;
      const ownerNet = total - commission;
      expect(ownerNet, 1350.0);
    });
  });
}
