import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase.dart';

final ratingsRepositoryProvider =
    Provider<RatingsRepository>((_) => RatingsRepository());

class RatingsRepository {
  /// Check if the rental is completed and not yet rated by [raterId].
  Future<({bool eligible, bool alreadyRated})> checkEligibility({
    required String rentalRequestId,
    required String? raterId,
  }) async {
    final rr = await supabase
        .from('rental_requests')
        .select('status')
        .eq('id', rentalRequestId)
        .maybeSingle();
    if (rr?['status']?.toString() != 'completed') {
      return (eligible: false, alreadyRated: false);
    }
    if (raterId != null) {
      final existing = await supabase
          .from('ratings')
          .select('id')
          .eq('rental_request_id', rentalRequestId)
          .eq('rater_id', raterId)
          .maybeSingle();
      if (existing != null) {
        return (eligible: false, alreadyRated: true);
      }
    }
    return (eligible: true, alreadyRated: false);
  }

  Future<void> submitRating({
    required String rentalRequestId,
    required String raterId,
    required String rateeId,
    required int score,
    String? comment,
  }) async {
    await supabase.from('ratings').insert({
      'rental_request_id': rentalRequestId,
      'rater_id': raterId,
      'ratee_id': rateeId,
      'score': score,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
  }
}
