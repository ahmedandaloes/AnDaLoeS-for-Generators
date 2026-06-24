/// Pure domain entity — no Flutter, no Supabase imports.
class Generator {
  const Generator({
    required this.id,
    required this.title,
    required this.capacityKva,
    required this.pricePerDay,
    required this.city,
    required this.governorate,
    required this.photos,
    required this.avgScore,
    required this.ratingCount,
    required this.fuelType,
    required this.useCases,
    required this.hireType,
    required this.fuelPolicy,
    required this.accessories,
    required this.createdAt,
    required this.companyName,
    required this.isVerified,
  });

  final String id;
  final String title;
  final double capacityKva;
  final double pricePerDay;
  final String city;
  final String governorate;
  final List<String> photos;
  final double avgScore;
  final int ratingCount;
  final String fuelType;
  final List<String> useCases;
  final String hireType;
  final String fuelPolicy;
  final List<String> accessories;
  final DateTime createdAt;
  final String companyName;
  final bool isVerified;

  factory Generator.fromMap(Map<String, dynamic> map) {
    final company = map['companies'] as Map<String, dynamic>?;
    return Generator(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      capacityKva: (map['capacity_kva'] as num?)?.toDouble() ?? 0,
      pricePerDay: (map['price_per_day'] as num?)?.toDouble() ?? 0,
      city: map['city']?.toString() ?? '',
      governorate: map['governorate']?.toString() ?? '',
      photos: _toStringList(map['photos']),
      avgScore: (map['avg_score'] as num?)?.toDouble() ?? 0,
      ratingCount: (map['rating_count'] as num?)?.toInt() ?? 0,
      fuelType: map['fuel_type']?.toString() ?? '',
      useCases: _toStringList(map['use_cases']),
      hireType: map['hire_type']?.toString() ?? 'dry_hire',
      fuelPolicy: map['fuel_policy']?.toString() ?? 'customer_provides',
      accessories: _toStringList(map['accessories']),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime(2000)
          : DateTime(2000),
      companyName: company?['name']?.toString() ?? '',
      isVerified:
          company?['verification_status']?.toString() == 'approved',
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'capacity_kva': capacityKva,
        'price_per_day': pricePerDay,
        'city': city,
        'governorate': governorate,
        'photos': photos,
        'avg_score': avgScore,
        'rating_count': ratingCount,
        'fuel_type': fuelType,
        'use_cases': useCases,
        'hire_type': hireType,
        'fuel_policy': fuelPolicy,
        'accessories': accessories,
        'created_at': createdAt.toIso8601String(),
      };

  static List<String> _toStringList(dynamic value) {
    if (value == null) return const [];
    if (value is List) return value.map((e) => e.toString()).toList();
    return const [];
  }
}
