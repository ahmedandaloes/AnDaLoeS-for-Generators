import 'package:flutter_test/flutter_test.dart';

import 'package:andaloes/features/ratings/domain/entities/rating.dart';

// ── Fixture ───────────────────────────────────────────────────────────────────

Map<String, dynamic> _ratingMap({
  String id = 'rating-1',
  String rentalRequestId = 'rent-1',
  String raterId = 'user-1',
  String rateeId = 'user-2',
  int score = 4,
  String? comment,
  String createdAt = '2026-06-10T12:00:00.000Z',
}) =>
    {
      'id': id,
      'rental_request_id': rentalRequestId,
      'rater_id': raterId,
      'ratee_id': rateeId,
      'score': score,
      if (comment != null) 'comment': comment,
      'created_at': createdAt,
    };

void main() {
  // ── Rating.fromMap – required fields ──────────────────────────────────────

  group('Rating.fromMap – required fields', () {
    test('id maps from "id"', () {
      expect(Rating.fromMap(_ratingMap()).id, 'rating-1');
    });

    test('rentalRequestId maps from "rental_request_id"', () {
      expect(Rating.fromMap(_ratingMap()).rentalRequestId, 'rent-1');
    });

    test('raterId maps from "rater_id"', () {
      expect(Rating.fromMap(_ratingMap()).raterId, 'user-1');
    });

    test('rateeId maps from "ratee_id"', () {
      expect(Rating.fromMap(_ratingMap()).rateeId, 'user-2');
    });

    test('score maps as int', () {
      expect(Rating.fromMap(_ratingMap()).score, 4);
    });

    test('createdAt parses ISO string', () {
      final r = Rating.fromMap(_ratingMap());
      expect(r.createdAt, DateTime.utc(2026, 6, 10, 12, 0, 0));
    });
  });

  // ── Rating.fromMap – optional comment ────────────────────────────────────

  group('Rating.fromMap – comment field', () {
    test('comment is null when absent', () {
      expect(Rating.fromMap(_ratingMap()).comment, isNull);
    });

    test('comment maps when present', () {
      expect(
        Rating.fromMap(_ratingMap(comment: 'Great service!')).comment,
        'Great service!',
      );
    });

    test('empty comment string maps correctly', () {
      expect(
        Rating.fromMap(_ratingMap(comment: '')).comment,
        '',
      );
    });
  });

  // ── Score range validation ────────────────────────────────────────────────

  group('Rating score values', () {
    for (final s in [1, 2, 3, 4, 5]) {
      test('score $s maps correctly', () {
        expect(Rating.fromMap(_ratingMap(score: s)).score, s);
      });
    }

    test('score can be provided as double and cast to int', () {
      final m = _ratingMap();
      m['score'] = 3.0; // API might return as double
      expect(Rating.fromMap(m).score, 3);
    });

    test('score 5 is maximum valid value', () {
      final r = Rating.fromMap(_ratingMap(score: 5));
      expect(r.score, inInclusiveRange(1, 5));
    });

    test('score 1 is minimum valid value', () {
      final r = Rating.fromMap(_ratingMap(score: 1));
      expect(r.score, inInclusiveRange(1, 5));
    });
  });

  // ── Rating direct construction ────────────────────────────────────────────

  group('Rating direct construction', () {
    final rating = Rating(
      id: 'r-99',
      rentalRequestId: 'rent-99',
      raterId: 'u-1',
      rateeId: 'u-2',
      score: 5,
      comment: 'Excellent!',
      createdAt: DateTime(2026, 1, 1),
    );

    test('all fields accessible', () {
      expect(rating.id, 'r-99');
      expect(rating.rentalRequestId, 'rent-99');
      expect(rating.raterId, 'u-1');
      expect(rating.rateeId, 'u-2');
      expect(rating.score, 5);
      expect(rating.comment, 'Excellent!');
      expect(rating.createdAt, DateTime(2026, 1, 1));
    });

    test('rater and ratee are different users', () {
      expect(rating.raterId, isNot(equals(rating.rateeId)));
    });
  });

  // ── Rating.fromMap – multiple ratings ────────────────────────────────────

  group('Rating.fromMap – list scenario', () {
    test('multiple ratings from maps produce correct scores', () {
      final maps = [
        _ratingMap(id: 'r-1', score: 5),
        _ratingMap(id: 'r-2', score: 3),
        _ratingMap(id: 'r-3', score: 1),
      ];
      final ratings = maps.map(Rating.fromMap).toList();
      expect(ratings.map((r) => r.score).toList(), [5, 3, 1]);
    });

    test('average score computed from a list of ratings', () {
      final scores = [5, 4, 3, 4, 5];
      final avg = scores.reduce((a, b) => a + b) / scores.length;
      expect(avg, closeTo(4.2, 0.001));
    });
  });
}
