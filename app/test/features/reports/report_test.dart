import 'package:flutter_test/flutter_test.dart';

import 'package:andaloes/features/reports/domain/entities/report.dart';

// ── Fixture ───────────────────────────────────────────────────────────────────

Map<String, dynamic> _reportMap({
  String id = 'rpt-1',
  String reporterId = 'user-1',
  String entityType = 'generator',
  String entityId = 'gen-1',
  String reason = 'misleading_info',
  String? details,
  String? status,
  String createdAt = '2026-06-22T09:00:00.000Z',
}) =>
    {
      'id': id,
      'reporter_id': reporterId,
      'entity_type': entityType,
      'entity_id': entityId,
      'reason': reason,
      if (details != null) 'details': details,
      if (status != null) 'status': status,
      'created_at': createdAt,
    };

void main() {
  // ── Report.fromMap – required fields ──────────────────────────────────────

  group('Report.fromMap – required fields', () {
    test('id maps from "id"', () {
      expect(Report.fromMap(_reportMap()).id, 'rpt-1');
    });

    test('reporterId maps from "reporter_id"', () {
      expect(Report.fromMap(_reportMap()).reporterId, 'user-1');
    });

    test('entityType maps from "entity_type"', () {
      expect(Report.fromMap(_reportMap()).entityType, 'generator');
    });

    test('entityId maps from "entity_id"', () {
      expect(Report.fromMap(_reportMap()).entityId, 'gen-1');
    });

    test('reason maps correctly', () {
      expect(Report.fromMap(_reportMap()).reason, 'misleading_info');
    });

    test('createdAt parses ISO string', () {
      final r = Report.fromMap(_reportMap());
      expect(r.createdAt, DateTime.utc(2026, 6, 22, 9, 0, 0));
    });
  });

  // ── Report.fromMap – optional fields ─────────────────────────────────────

  group('Report.fromMap – optional fields', () {
    test('details is null when absent', () {
      expect(Report.fromMap(_reportMap()).details, isNull);
    });

    test('details maps when present', () {
      expect(
        Report.fromMap(_reportMap(details: 'Photos do not match the actual unit')).details,
        'Photos do not match the actual unit',
      );
    });

    test('status defaults to "open" when absent', () {
      expect(Report.fromMap(_reportMap()).status, 'open');
    });

    test('status maps when present', () {
      expect(Report.fromMap(_reportMap(status: 'resolved')).status, 'resolved');
    });

    test('status "closed" maps correctly', () {
      expect(Report.fromMap(_reportMap(status: 'closed')).status, 'closed');
    });
  });

  // ── Report entity types ───────────────────────────────────────────────────

  group('Report entity types', () {
    for (final type in ['generator', 'company', 'user']) {
      test('entityType "$type" maps correctly', () {
        expect(Report.fromMap(_reportMap(entityType: type)).entityType, type);
      });
    }
  });

  // ── Report reason values ──────────────────────────────────────────────────

  group('Report reason values', () {
    for (final reason in [
      'misleading_info',
      'inappropriate_content',
      'fraud',
      'spam',
      'other',
    ]) {
      test('reason "$reason" maps correctly', () {
        expect(Report.fromMap(_reportMap(reason: reason)).reason, reason);
      });
    }
  });

  // ── Report direct construction ────────────────────────────────────────────

  group('Report direct construction', () {
    final r = Report(
      id: 'r-99',
      reporterId: 'u-1',
      entityType: 'company',
      entityId: 'comp-5',
      reason: 'fraud',
      details: 'Did not deliver the generator',
      createdAt: DateTime(2026, 5, 10),
    );

    test('id accessible', () => expect(r.id, 'r-99'));
    test('entityType accessible', () => expect(r.entityType, 'company'));
    test('reason accessible', () => expect(r.reason, 'fraud'));
    test('details accessible', () => expect(r.details, 'Did not deliver the generator'));
    test('default status is "open"', () => expect(r.status, 'open'));
    test('createdAt accessible', () => expect(r.createdAt, DateTime(2026, 5, 10)));
  });
}
