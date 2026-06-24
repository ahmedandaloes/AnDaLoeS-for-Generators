/// Data transfer object for the rental_requests table.
/// Carries all columns returned by the full-row SELECT — no Flutter/Riverpod deps.
class RentalModel {
  const RentalModel({
    required this.id,
    required this.generatorId,
    required this.companyId,
    required this.customerId,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.priceTotal,
    required this.status,
    required this.createdAt,
    this.note,
    this.depositAmount,
    this.deliveryAddress,
    this.deliveryTime,
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
  final DateTime createdAt;
  final String? note;
  final double? depositAmount;
  final String? deliveryAddress;
  final String? deliveryTime;

  factory RentalModel.fromMap(Map<String, dynamic> m) => RentalModel(
        id: m['id'] as String,
        generatorId: m['generator_id'] as String,
        companyId: m['company_id'] as String,
        customerId: m['customer_id'] as String,
        startDate: m['start_date'] as String,
        endDate: m['end_date'] as String,
        totalDays: (m['total_days'] as num).toInt(),
        priceTotal: (m['price_total'] as num).toDouble(),
        status: m['status'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
        note: m['note'] as String?,
        depositAmount: (m['deposit_amount'] as num?)?.toDouble(),
        deliveryAddress: m['delivery_address'] as String?,
        deliveryTime: m['delivery_time'] as String?,
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
        'created_at': createdAt.toIso8601String(),
        if (note != null) 'note': note,
        if (depositAmount != null) 'deposit_amount': depositAmount,
        if (deliveryAddress != null) 'delivery_address': deliveryAddress,
        if (deliveryTime != null) 'delivery_time': deliveryTime,
      };
}
