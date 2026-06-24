class Rating {
  const Rating({
    required this.id,
    required this.rentalRequestId,
    required this.raterId,
    required this.rateeId,
    required this.score,
    required this.createdAt,
    this.comment,
  });

  final String id;
  final String rentalRequestId;
  final String raterId;
  final String rateeId;
  final int score;
  final String? comment;
  final DateTime createdAt;

  factory Rating.fromMap(Map<String, dynamic> map) => Rating(
        id: map['id'] as String,
        rentalRequestId: map['rental_request_id'] as String,
        raterId: map['rater_id'] as String,
        rateeId: map['ratee_id'] as String,
        score: (map['score'] as num).toInt(),
        comment: map['comment'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
