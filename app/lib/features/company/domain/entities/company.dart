class Company {
  const Company({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.status,
    this.city,
    this.governorate,
    this.description,
    this.verificationStatus,
    this.createdAt,
  });

  final String id;
  final String ownerId;
  final String name;
  final String status; // 'pending' | 'approved' | 'rejected'
  final String? city;
  final String? governorate;
  final String? description;
  final String? verificationStatus; // 'pending' | 'approved' | 'rejected'
  final DateTime? createdAt;

  factory Company.fromMap(Map<String, dynamic> map) {
    return Company(
      id: map['id']?.toString() ?? '',
      ownerId: map['owner_user_id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      status: map['status']?.toString() ?? 'pending',
      city: map['city']?.toString(),
      governorate: map['governorate']?.toString(),
      description: map['description']?.toString(),
      verificationStatus: map['verification_status']?.toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'owner_user_id': ownerId,
        'name': name,
        'status': status,
        if (city != null) 'city': city,
        if (governorate != null) 'governorate': governorate,
        if (description != null) 'description': description,
      };
}
