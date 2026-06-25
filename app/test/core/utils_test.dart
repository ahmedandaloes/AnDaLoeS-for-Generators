// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:andaloes/core/utils/commission.dart';
import 'package:andaloes/core/utils/pricing.dart';
import 'package:andaloes/core/utils/tax.dart';
import 'package:andaloes/core/utils/db_error.dart';
import 'package:andaloes/core/theme/status_colors.dart';

/// Minimal stub [ColorScheme] so we can call status-color functions
/// without a real Flutter widget tree.
final _cs = ColorScheme.fromSeed(seedColor: Colors.blue);

void main() {
  // ── projectCommission ──────────────────────────────────────────────────────

  group('projectCommission – percentage', () {
    test('10% of 5000 yields commission 500 and net 4500', () {
      final r = projectCommission(5000, (type: 'percentage', value: 0.10));
      expect(r.commission, 500.0);
      expect(r.net, 4500.0);
    });

    test('label carries human-readable percent', () {
      final r = projectCommission(1000, (type: 'percentage', value: 0.15));
      expect(r.label, '15% platform fee');
    });

    test('1% of 200 rounds to 2.0', () {
      final r = projectCommission(200, (type: 'percentage', value: 0.01));
      expect(r.commission, closeTo(2.0, 0.001));
    });
  });

  group('projectCommission – fixed', () {
    test('fixed 50 EGP on 5000 total', () {
      final r = projectCommission(5000, (type: 'fixed', value: 50));
      expect(r.commission, 50.0);
      expect(r.net, 4950.0);
    });

    test('fixed label uses EGP prefix', () {
      final r = projectCommission(1000, (type: 'fixed', value: 75));
      expect(r.label, 'EGP 75 platform fee');
    });

    test('fixed commission capped when it exceeds total', () {
      final r = projectCommission(30, (type: 'fixed', value: 50));
      expect(r.commission, 30.0); // clamped to total
      expect(r.net, 0.0);
    });
  });

  group('projectCommission – null rule', () {
    test('null rule → zero commission and full net', () {
      final r = projectCommission(8000, null);
      expect(r.commission, 0.0);
      expect(r.net, 8000.0);
      expect(r.label, '');
    });

    test('zero total with null rule stays zero', () {
      final r = projectCommission(0, null);
      expect(r.net, 0.0);
    });
  });

  // ── bestRentalPrice ────────────────────────────────────────────────────────

  group('bestRentalPrice – day-only', () {
    test('0 days costs 0', () {
      expect(bestRentalPrice(days: 0, perDay: 500), 0.0);
    });

    test('1 day = perDay', () {
      expect(bestRentalPrice(days: 1, perDay: 300), 300.0);
    });

    test('3 days = 3 × perDay when no week/month', () {
      expect(bestRentalPrice(days: 3, perDay: 500), 1500.0);
    });

    test('6 days just below a week uses daily', () {
      // No perWeek supplied → pure daily
      expect(bestRentalPrice(days: 6, perDay: 200), 1200.0);
    });
  });

  group('bestRentalPrice – weekly tier', () {
    test('exactly 7 days uses perWeek if cheaper', () {
      // 7 × 500 = 3500 vs perWeek 3000 → should pick 3000
      expect(
        bestRentalPrice(days: 7, perDay: 500, perWeek: 3000),
        3000.0,
      );
    });

    test('exactly 7 days stays daily if week is more expensive', () {
      // 7 × 200 = 1400 vs perWeek 2000 → should stay daily
      expect(
        bestRentalPrice(days: 7, perDay: 200, perWeek: 2000),
        lessThanOrEqualTo(1400.0),
      );
    });

    test('10 days: 1 week + 3 days beats 10 daily', () {
      // 1 week (3000) + 3 days (1500) = 4500 < 10 × 500 = 5000
      expect(
        bestRentalPrice(days: 10, perDay: 500, perWeek: 3000),
        4500.0,
      );
    });

    test('result never exceeds plain daily total', () {
      final price = bestRentalPrice(days: 5, perDay: 500, perWeek: 9000);
      expect(price, lessThanOrEqualTo(5 * 500));
    });
  });

  group('bestRentalPrice – monthly tier', () {
    test('exactly 30 days uses perMonth if cheaper', () {
      // 30 × 500 = 15000 vs perMonth 10000
      expect(
        bestRentalPrice(days: 30, perDay: 500, perMonth: 10000),
        10000.0,
      );
    });

    test('31 days: 1 month + 1 day is cheapest', () {
      // 1 month (10000) + 1 day (500) = 10500 < 31 × 500 = 15500
      expect(
        bestRentalPrice(days: 31, perDay: 500, perMonth: 10000),
        10500.0,
      );
    });

    test('60 days: 2 months beats 2 × 30 days', () {
      // 2 × 10000 = 20000 < 60 × 500 = 30000
      expect(
        bestRentalPrice(days: 60, perDay: 500, perMonth: 10000),
        20000.0,
      );
    });

    test('month+week+day combined for 37 days', () {
      // 1 month (10000) + 1 week (3000) + 0 days = 13000
      // vs 37 × 500 = 18500 → 13000 wins
      expect(
        bestRentalPrice(
          days: 37,
          perDay: 500,
          perWeek: 3000,
          perMonth: 10000,
        ),
        13000.0,
      );
    });

    test('result never exceeds plain daily total with month tier', () {
      final price = bestRentalPrice(
        days: 5,
        perDay: 500,
        perWeek: 9000,
        perMonth: 99999,
      );
      expect(price, lessThanOrEqualTo(5 * 500));
    });

    test('missing monthly tier falls back to week+day', () {
      // 10 days with only perWeek: 1 week (3000) + 3 days (1500) = 4500
      expect(
        bestRentalPrice(days: 10, perDay: 500, perWeek: 3000),
        4500.0,
      );
    });
  });

  // ── vatBreakdown ───────────────────────────────────────────────────────────

  group('vatBreakdown', () {
    test('14% VAT extracted from inclusive total of 114', () {
      final b = vatBreakdown(114, 0.14);
      expect(b.subtotal, closeTo(100, 0.001));
      expect(b.vat, closeTo(14, 0.001));
    });

    test('subtotal + vat equals total', () {
      final b = vatBreakdown(1500, 0.14);
      expect(b.subtotal + b.vat, closeTo(1500, 0.001));
    });

    test('zero rate returns full total as subtotal, no vat', () {
      final b = vatBreakdown(500, 0);
      expect(b.subtotal, 500);
      expect(b.vat, 0);
    });

    test('negative total returns subtotal=total, vat=0', () {
      // Guard: negative amounts treated as zero-total path
      final b = vatBreakdown(-100, 0.14);
      expect(b.vat, 0);
    });

    test('5% rate on 1050 inclusive total', () {
      final b = vatBreakdown(1050, 0.05);
      expect(b.subtotal, closeTo(1000, 0.001));
      expect(b.vat, closeTo(50, 0.001));
    });
  });

  group('vatShownAtBooking', () {
    test('always → shown', () => expect(vatShownAtBooking('always'), true));
    test(
      'on_invoice_request → not shown',
      () => expect(vatShownAtBooking('on_invoice_request'), false),
    );
    test(
      'empty string → not shown',
      () => expect(vatShownAtBooking(''), false),
    );
  });

  // ── friendlyDbError ────────────────────────────────────────────────────────

  group('friendlyDbError', () {
    test('no-overlap constraint → friendly already-booked message', () {
      final msg = friendlyDbError(
        Exception('violates exclusion constraint "rental_requests_no_overlap"'),
      );
      expect(msg.toLowerCase(), contains('already booked'));
    });

    test('generic exclusion constraint keyword → friendly message', () {
      final msg = friendlyDbError(Exception('exclusion constraint violated'));
      expect(msg.toLowerCase(), contains('already booked'));
    });

    test('Postgres 23P01 code → friendly message', () {
      final msg = friendlyDbError(Exception('ERROR 23p01: exclusion'));
      expect(msg.toLowerCase(), contains('already booked'));
    });

    test('unknown error uses fallback', () {
      expect(friendlyDbError(Exception('boom'), fallback: 'Oops'), 'Oops');
    });

    test('default fallback is sensible', () {
      final msg = friendlyDbError(Exception('unexpected'));
      expect(msg, isNotEmpty);
    });
  });

  // ── rentalStatusColor ──────────────────────────────────────────────────────

  group('rentalStatusColor', () {
    test('pending → orange', () {
      final color = rentalStatusColor('pending', _cs);
      expect(color, Colors.orange.shade700);
    });

    test('accepted → green', () {
      final color = rentalStatusColor('accepted', _cs);
      expect(color, Colors.green.shade600);
    });

    test('active → scheme primary', () {
      final color = rentalStatusColor('active', _cs);
      expect(color, _cs.primary);
    });

    test('completed → dark green', () {
      final color = rentalStatusColor('completed', _cs);
      expect(color, Colors.green.shade700);
    });

    test('rejected → error color', () {
      final color = rentalStatusColor('rejected', _cs);
      expect(color, _cs.error);
    });

    test('cancelled → onSurfaceVariant', () {
      final color = rentalStatusColor('cancelled', _cs);
      expect(color, _cs.onSurfaceVariant);
    });

    test('unknown status → onSurfaceVariant', () {
      final color = rentalStatusColor('unknown_xyz', _cs);
      expect(color, _cs.onSurfaceVariant);
    });
  });

  // ── generatorStatusColor ──────────────────────────────────────────────────

  group('generatorStatusColor', () {
    test('available → green', () {
      expect(generatorStatusColor('available', _cs), Colors.green.shade600);
    });

    test('pending → orange', () {
      expect(generatorStatusColor('pending', _cs), Colors.orange.shade700);
    });

    test('unavailable → onSurfaceVariant', () {
      expect(generatorStatusColor('unavailable', _cs), _cs.onSurfaceVariant);
    });

    test('rejected → error', () {
      expect(generatorStatusColor('rejected', _cs), _cs.error);
    });

    test('unknown → onSurfaceVariant fallback', () {
      expect(generatorStatusColor('mystery', _cs), _cs.onSurfaceVariant);
    });
  });

  // ── qualityColor ──────────────────────────────────────────────────────────

  group('qualityColor', () {
    test('80 → green', () {
      expect(qualityColor(80), Colors.green.shade700);
    });

    test('100 → green', () {
      expect(qualityColor(100), Colors.green.shade700);
    });

    test('50 → amber', () {
      expect(qualityColor(50), Colors.orange.shade800);
    });

    test('79 → amber (just below green threshold)', () {
      expect(qualityColor(79), Colors.orange.shade800);
    });

    test('49 → red (below 50)', () {
      expect(qualityColor(49), Colors.red.shade700);
    });

    test('0 → red', () {
      expect(qualityColor(0), Colors.red.shade700);
    });
  });
}
