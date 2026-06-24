import '../../domain/entities/owner_request.dart';

class OwnerRequestModel extends OwnerRequest {
  const OwnerRequestModel({
    required super.id,
    required super.generatorId,
    required super.companyId,
    required super.customerId,
    required super.status,
    required super.startDate,
    required super.endDate,
    required super.totalDays,
    required super.priceTotal,
    required super.createdAt,
    super.depositAmount,
    super.deliveryAddress,
    super.deliveryTime,
    super.note,
  });

  factory OwnerRequestModel.fromMap(Map<String, dynamic> map) {
    final base = OwnerRequest.fromMap(map);
    return OwnerRequestModel(
      id: base.id,
      generatorId: base.generatorId,
      companyId: base.companyId,
      customerId: base.customerId,
      status: base.status,
      startDate: base.startDate,
      endDate: base.endDate,
      totalDays: base.totalDays,
      priceTotal: base.priceTotal,
      depositAmount: base.depositAmount,
      deliveryAddress: base.deliveryAddress,
      deliveryTime: base.deliveryTime,
      note: base.note,
      createdAt: base.createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'generator_id': generatorId,
        'company_id': companyId,
        'customer_id': customerId,
        'status': status,
        'start_date': startDate,
        'end_date': endDate,
        'total_days': totalDays,
        'price_total': priceTotal,
        'deposit_amount': depositAmount,
        if (deliveryAddress != null) 'delivery_address': deliveryAddress,
        if (deliveryTime != null) 'delivery_time': deliveryTime,
        if (note != null) 'note': note,
        'created_at': createdAt.toIso8601String(),
      };
}
