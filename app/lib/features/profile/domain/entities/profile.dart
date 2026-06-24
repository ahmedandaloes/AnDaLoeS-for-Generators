class Profile {
  const Profile({
    required this.id,
    required this.role,
    this.fullName,
    this.phone,
    this.avatarUrl,
    this.joinedAt,
  });

  final String id;
  final String role; // 'customer' | 'owner' | 'admin'
  final String? fullName;
  final String? phone;
  final String? avatarUrl;
  final DateTime? joinedAt;

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id']?.toString() ?? '',
      role: map['role']?.toString() ?? 'customer',
      fullName: map['full_name']?.toString(),
      phone: map['phone']?.toString(),
      avatarUrl: map['avatar_url']?.toString(),
      joinedAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }
}
