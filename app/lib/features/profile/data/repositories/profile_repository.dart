import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/supabase.dart';
import '../../domain/entities/profile.dart';
import '../../domain/repositories/i_profile_repository.dart';

final profileRepositoryProvider =
    Provider<IProfileRepository>((_) => ProfileRepository());

class ProfileRepository implements IProfileRepository {
  @override
  Future<Profile?> fetchProfile(String userId) async {
    final data = await supabase
        .from('profiles')
        .select('id, role, full_name, phone, avatar_url, created_at')
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;
    return Profile.fromMap(data);
  }

  @override
  Future<void> updateProfile(String userId, Map<String, dynamic> data) async {
    await supabase.from('profiles').update(data).eq('id', userId);
  }

  @override
  Future<Map<String, dynamic>> fetchStats(String userId) async {
    final rentals = await supabase
        .from('rental_requests')
        .select('status, price_total, created_at')
        .eq('customer_id', userId);
    final list = (rentals as List).cast<Map<String, dynamic>>();
    final completed = list.where((r) => r['status'] == 'completed').toList();
    final totalSpent = completed.fold<double>(
        0, (s, r) => s + ((r['price_total'] as num?)?.toDouble() ?? 0));
    return {
      'total_rentals': completed.length,
      'total_spent': totalSpent,
    };
  }
}
