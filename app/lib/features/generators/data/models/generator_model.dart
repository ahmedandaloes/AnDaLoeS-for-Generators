import '../../domain/entities/generator.dart';

/// Data-layer model — bridges raw Supabase JSON to domain [Generator] entity.
/// Callers outside this feature should use [Generator] directly.
class GeneratorModel extends Generator {
  const GeneratorModel({
    required super.id,
    required super.title,
    required super.capacityKva,
    required super.pricePerDay,
    required super.city,
    required super.governorate,
    required super.photos,
    required super.avgScore,
    required super.ratingCount,
    required super.fuelType,
    required super.useCases,
    required super.hireType,
    required super.fuelPolicy,
    required super.accessories,
    required super.createdAt,
    required super.companyName,
    required super.isVerified,
  });

  factory GeneratorModel.fromMap(Map<String, dynamic> map) {
    final base = Generator.fromMap(map);
    return GeneratorModel(
      id: base.id,
      title: base.title,
      capacityKva: base.capacityKva,
      pricePerDay: base.pricePerDay,
      city: base.city,
      governorate: base.governorate,
      photos: base.photos,
      avgScore: base.avgScore,
      ratingCount: base.ratingCount,
      fuelType: base.fuelType,
      useCases: base.useCases,
      hireType: base.hireType,
      fuelPolicy: base.fuelPolicy,
      accessories: base.accessories,
      createdAt: base.createdAt,
      companyName: base.companyName,
      isVerified: base.isVerified,
    );
  }
}
