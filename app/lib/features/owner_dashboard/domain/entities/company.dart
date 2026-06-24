class CompanyEntity {
  const CompanyEntity({
    required this.id,
    required this.ownerUserId,
    required this.name,
    required this.verificationStatus,
    this.description,
    this.phone,
    this.logoUrl,
    required this.createdAt,
  });

  final String id;
  final String ownerUserId;
  final String name;
  final String verificationStatus;
  final String? description;
  final String? phone;
  final String? logoUrl;
  final DateTime createdAt;

  bool get isApproved => verificationStatus == 'approved';

  factory CompanyEntity.fromMap(Map<String, dynamic> map) => CompanyEntity(
        id: map['id'] as String,
        ownerUserId: map['owner_user_id'] as String,
        name: map['name'] as String,
        verificationStatus:
            map['verification_status']?.toString() ?? 'pending',
        description: map['description'] as String?,
        phone: map['phone'] as String?,
        logoUrl: map['logo_url'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'owner_user_id': ownerUserId,
        'name': name,
        'verification_status': verificationStatus,
        if (description != null) 'description': description,
        if (phone != null) 'phone': phone,
        if (logoUrl != null) 'logo_url': logoUrl,
        'created_at': createdAt.toIso8601String(),
      };
}
