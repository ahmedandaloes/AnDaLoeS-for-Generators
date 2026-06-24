import '../../domain/entities/rental_request.dart';

class RentalRequestModel extends RentalRequestEntity {
  const RentalRequestModel({
    required super.id,
    required super.generatorId,
    required super.companyId,
    required super.customerId,
    required super.startDate,
    required super.endDate,
    required super.totalDays,
    required super.priceTotal,
    required super.status,
    super.note,
    required super.createdAt,
  });

  factory RentalRequestModel.fromMap(Map<String, dynamic> map) {
    final entity = RentalRequestEntity.fromMap(map);
    return RentalRequestModel(
      id: entity.id,
      generatorId: entity.generatorId,
      companyId: entity.companyId,
      customerId: entity.customerId,
      startDate: entity.startDate,
      endDate: entity.endDate,
      totalDays: entity.totalDays,
      priceTotal: entity.priceTotal,
      status: entity.status,
      note: entity.note,
      createdAt: entity.createdAt,
    );
  }
}
