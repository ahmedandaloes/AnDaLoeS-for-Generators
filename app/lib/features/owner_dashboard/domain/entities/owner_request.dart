class OwnerRequest {
  const OwnerRequest({
    required this.id,
    required this.generatorId,
    required this.companyId,
    required this.customerId,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.priceTotal,
    required this.createdAt,
    this.depositAmount = 0,
    this.deliveryAddress,
    this.deliveryTime,
    this.note,
  });

  final String id;
  final String generatorId;
  final String companyId;
  final String customerId;
  final String status;
  final String startDate;
  final String endDate;
  final int totalDays;
  final double priceTotal;
  final double depositAmount;
  final String? deliveryAddress;
  final String? deliveryTime;
  final String? note;
  final DateTime createdAt;

  bool get isPending => status == 'pending';
  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';

  factory OwnerRequest.fromMap(Map<String, dynamic> map) => OwnerRequest(
        id: map['id'] as String,
        generatorId: map['generator_id'] as String,
        companyId: map['company_id'] as String,
        customerId: map['customer_id'] as String,
        status: map['status']?.toString() ?? 'pending',
        startDate: map['start_date'] as String,
        endDate: map['end_date'] as String,
        totalDays: (map['total_days'] as num?)?.toInt() ?? 1,
        priceTotal: (map['price_total'] as num?)?.toDouble() ?? 0,
        depositAmount: (map['deposit_amount'] as num?)?.toDouble() ?? 0,
        deliveryAddress: map['delivery_address'] as String?,
        deliveryTime: map['delivery_time'] as String?,
        note: map['note'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
