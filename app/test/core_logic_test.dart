import 'package:flutter_test/flutter_test.dart';

import 'package:andaloes/core/utils/commission.dart';
import 'package:andaloes/core/utils/db_error.dart';
import 'package:andaloes/core/utils/ics.dart';
import 'package:andaloes/core/constants/generator_sizes.dart';
import 'package:andaloes/core/constants/generator_use_cases.dart';

void main() {
  group('projectCommission', () {
    test('percentage rate', () {
      final r = projectCommission(5000, (type: 'percentage', value: 0.10));
      expect(r.commission, 500);
      expect(r.net, 4500);
      expect(r.label, '10% platform fee');
    });

    test('fixed rate', () {
      final r = projectCommission(5000, (type: 'fixed', value: 50));
      expect(r.commission, 50);
      expect(r.net, 4950);
    });

    test('null rule means no commission', () {
      final r = projectCommission(5000, null);
      expect(r.commission, 0);
      expect(r.net, 5000);
    });

    test('commission never exceeds the total', () {
      final r = projectCommission(40, (type: 'fixed', value: 50));
      expect(r.commission, 40);
      expect(r.net, 0);
    });
  });

  group('friendlyDbError', () {
    test('overlap constraint maps to a friendly booking message', () {
      final m = friendlyDbError(
          Exception('violates exclusion constraint "rental_requests_no_overlap"'));
      expect(m.toLowerCase(), contains('already booked'));
    });

    test('unknown error falls back', () {
      expect(friendlyDbError(Exception('boom'), fallback: 'X'), 'X');
    });
  });

  group('generator sizes', () {
    test('kW is 0.8 of kVA', () {
      expect(kvaToKw(100), 80);
      expect(kvaToKw(150), 120);
    });

    test('label shows both units', () {
      expect(generatorSizeLabel(100), '100 kVA · 80 kW');
    });
  });

  group('useCaseLabel', () {
    test('capitalizes', () => expect(useCaseLabel('events'), 'Events'));
    test('handles empty', () => expect(useCaseLabel(''), ''));
  });

  group('buildRentalIcs', () {
    test('produces a valid all-day VEVENT (exclusive end date)', () {
      final ics = buildRentalIcs(
        id: 'abc',
        title: 'AnDo',
        start: DateTime(2026, 1, 10),
        end: DateTime(2026, 1, 15),
        location: 'Cairo',
      );
      expect(ics, contains('BEGIN:VEVENT'));
      expect(ics, contains('DTSTART;VALUE=DATE:20260110'));
      expect(ics, contains('DTEND;VALUE=DATE:20260116'));
      expect(ics, contains('SUMMARY:Generator rental: AnDo'));
      expect(ics, contains('LOCATION:Cairo'));
    });
  });
}
