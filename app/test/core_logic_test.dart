import 'package:flutter_test/flutter_test.dart';

import 'package:andaloes/core/utils/commission.dart';
import 'package:andaloes/core/utils/pricing.dart';
import 'package:andaloes/core/utils/db_error.dart';
import 'package:andaloes/core/utils/ics.dart';
import 'package:andaloes/core/constants/generator_sizes.dart';
import 'package:andaloes/core/constants/generator_use_cases.dart';
import 'package:andaloes/features/generators/presentation/widgets/generator_filter.dart';

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

  group('GeneratorFilter persistence', () {
    test('round-trips through JSON (query excluded)', () {
      const f = GeneratorFilter(
        query: 'transient',
        governorate: 'Cairo',
        maxKva: 250,
        maxPrice: 1200,
        fuelType: 'diesel',
        useCases: {'events', 'construction'},
        sort: GeneratorSortBy.priceLow,
      );
      final back = GeneratorFilter.fromJson(f.toJson());
      expect(back.governorate, 'Cairo');
      expect(back.maxKva, 250);
      expect(back.maxPrice, 1200);
      expect(back.fuelType, 'diesel');
      expect(back.useCases, {'events', 'construction'});
      expect(back.sort, GeneratorSortBy.priceLow);
      expect(back.query, ''); // search text is not persisted
    });

    test('empty filter round-trips to defaults', () {
      final back = GeneratorFilter.fromJson(const GeneratorFilter().toJson());
      expect(back.hasActiveFilters, false);
      expect(back.sort, GeneratorSortBy.newest);
    });
  });

  group('bestRentalPrice', () {
    test('day-only when no week/month rates', () {
      expect(bestRentalPrice(days: 3, perDay: 500), 1500);
    });

    test('picks the cheapest tier combination', () {
      // 10 days: 1 week (3000) + 3 days (1500) = 4500 beats 10×500 = 5000.
      expect(
        bestRentalPrice(days: 10, perDay: 500, perWeek: 3000, perMonth: 10000),
        4500,
      );
    });

    test('uses a month when it is cheapest', () {
      // 30 days: month 10000 beats 30×500 = 15000.
      expect(
        bestRentalPrice(days: 30, perDay: 500, perWeek: 3000, perMonth: 10000),
        10000,
      );
    });

    test('never exceeds the plain daily total', () {
      final p =
          bestRentalPrice(days: 5, perDay: 500, perWeek: 9000, perMonth: 99999);
      expect(p, lessThanOrEqualTo(5 * 500));
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
