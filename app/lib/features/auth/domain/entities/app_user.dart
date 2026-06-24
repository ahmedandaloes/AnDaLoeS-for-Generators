class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.role,
    required this.isAnonymous,
    this.createdAt,
  });

  final String id;
  final String? email;
  final String role; // 'customer' | 'owner' | 'admin'
  final bool isAnonymous;
  final DateTime? createdAt;

  factory AppUser.fromMap(Map<String, dynamic> map, {bool isAnonymous = false}) {
    return AppUser(
      id: map['id']?.toString() ?? '',
      email: map['email']?.toString(),
      role: map['role']?.toString() ?? 'customer',
      isAnonymous: isAnonymous,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }
}
