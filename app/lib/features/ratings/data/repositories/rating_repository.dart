import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase.dart';
import '../../domain/entities/rating.dart';
import '../../domain/repositories/i_rating_repository.dart';

final ratingRepositoryProvider =
    Provider<RatingRepository>((_) => RatingRepository());

class RatingRepository implements IRatingRepository {
  @override
  Future<bool> hasRated(String rentalRequestId, String raterId) async {
    final existing = await supabase
        .from('ratings')
        .select('id')
        .eq('rental_request_id', rentalRequestId)
        .eq('rater_id', raterId)
        .maybeSingle();
    return existing != null;
  }

  @override
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

  @override
  Future<List<Rating>> fetchByRatee(String rateeId) async {
    final data = await supabase
        .from('ratings')
        .select()
        .eq('ratee_id', rateeId)
        .order('created_at', ascending: false);
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(Rating.fromMap)
        .toList();
  }
}
