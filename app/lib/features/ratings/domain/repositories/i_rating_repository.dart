import '../entities/rating.dart';

abstract interface class IRatingRepository {
  Future<void> submitRating({
    required String rentalRequestId,
    required String raterId,
    required String rateeId,
    required int score,
    String? comment,
  });
  Future<List<Rating>> fetchByRatee(String rateeId);
  Future<bool> hasRated(String rentalRequestId, String raterId);
}
