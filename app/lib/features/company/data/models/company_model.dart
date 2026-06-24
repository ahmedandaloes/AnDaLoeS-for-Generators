import '../../domain/entities/company.dart';

class CompanyModel extends Company {
  const CompanyModel({
    required super.id,
    required super.ownerId,
    required super.name,
    required super.status,
    super.city,
    super.governorate,
    super.description,
    super.verificationStatus,
    super.createdAt,
  });

  factory CompanyModel.fromMap(Map<String, dynamic> map) {
    final base = Company.fromMap(map);
    return CompanyModel(
      id: base.id,
      ownerId: base.ownerId,
      name: base.name,
      status: base.status,
      city: base.city,
      governorate: base.governorate,
      description: base.description,
      verificationStatus: base.verificationStatus,
      createdAt: base.createdAt,
    );
  }
}
