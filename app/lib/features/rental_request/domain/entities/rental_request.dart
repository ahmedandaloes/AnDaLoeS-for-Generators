class RentalRequestEntity {
  const RentalRequestEntity({
    required this.id,
    required this.generatorId,
    required this.companyId,
    required this.customerId,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.priceTotal,
    required this.status,
    this.note,
    required this.createdAt,
  });

  final String id;
  final String generatorId;
  final String companyId;
  final String customerId;
  final String startDate;
  final String endDate;
  final int totalDays;
  final double priceTotal;
  final String status;
  final String? note;
  final DateTime createdAt;

  factory RentalRequestEntity.fromMap(Map<String, dynamic> map) =>
      RentalRequestEntity(
        id: map['id'] as String,
        generatorId: map['generator_id'] as String,
        companyId: map['company_id'] as String,
        customerId: map['customer_id'] as String,
        startDate: map['start_date'] as String,
        endDate: map['end_date'] as String,
        totalDays: (map['total_days'] as num).toInt(),
        priceTotal: (map['price_total'] as num).toDouble(),
        status: map['status'] as String,
        note: map['note'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'generator_id': generatorId,
        'company_id': companyId,
        'customer_id': customerId,
        'start_date': startDate,
        'end_date': endDate,
        'total_days': totalDays,
        'price_total': priceTotal,
        'status': status,
        if (note != null) 'note': note,
        'created_at': createdAt.toIso8601String(),
      };
}
