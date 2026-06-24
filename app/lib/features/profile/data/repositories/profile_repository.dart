import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions, UserAttributes;

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

  @override
  Future<Map<String, dynamic>?> fetchProfileData(String uid) async {
    return await supabase
        .from('profiles')
        .select('full_name, phone, role, avatar_url')
        .eq('id', uid)
        .maybeSingle();
  }

  @override
  Future<Map<String, num>> fetchRentalStats(String uid) async {
    final data = await supabase
        .from('rental_requests')
        .select('status, price_total, created_at')
        .eq('customer_id', uid);
    final list = (data as List).cast<Map<String, dynamic>>();
    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month);
    final lastMonthStart = DateTime(now.year, now.month - 1);
    num totalSpent = 0;
    num thisMonthSpent = 0;
    num lastMonthSpent = 0;
    for (final r in list) {
      if (r['status'] == 'completed') {
        final price = (r['price_total'] as num?) ?? 0;
        totalSpent += price;
        try {
          final dt = DateTime.parse(r['created_at'].toString());
          if (!dt.isBefore(thisMonthStart)) {
            thisMonthSpent += price;
          } else if (!dt.isBefore(lastMonthStart)) {
            lastMonthSpent += price;
          }
        } catch (_) {}
      }
    }
    return {
      'total': list.length,
      'active': list.where((r) => r['status'] == 'active').length,
      'completed': list.where((r) => r['status'] == 'completed').length,
      'pending': list.where((r) => r['status'] == 'pending').length,
      'total_spent': totalSpent,
      'this_month_spent': thisMonthSpent,
      'last_month_spent': lastMonthSpent,
    };
  }

  @override
  Future<int> fetchPendingRequestsCount(String uid) async {
    final data = await supabase
        .from('rental_requests')
        .select(
            'id, generators!inner(company_id, companies!inner(owner_user_id))')
        .eq('status', 'pending')
        .eq('generators.companies.owner_user_id', uid);
    return (data as List).length;
  }

  @override
  Future<String> uploadAvatar(
      String uid, Uint8List bytes, String ext) async {
    final storagePath = '$uid/avatar.$ext';
    await supabase.storage.from('avatars').uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(
            contentType: 'image/$ext',
            upsert: true,
          ),
        );
    final publicUrl =
        supabase.storage.from('avatars').getPublicUrl(storagePath);
    await supabase
        .from('profiles')
        .update({'avatar_url': publicUrl}).eq('id', uid);
    return publicUrl;
  }

  @override
  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  @override
  Future<void> upgradeAnonymousAccount(
      String email, String password) async {
    await supabase.auth
        .updateUser(UserAttributes(email: email, password: password));
  }
}
